const fs = require("fs");
const crypto = require("crypto");
const { Client } = require("pg");

const NAMESPACE = "e9089519-c6bd-41e8-9a54-6cb6d9da98d8";
const SCHEMA_MIGRATION = "20260910165527_create_catalog_schema.sql";
const ADVISORY_LOCK_KEY = "hourtv:catalog-bootstrap:v1";

const fieldsDef = {
  language: [
    { name: "id", type: "uuid" },
    { name: "code", type: "text" },
    { name: "name", type: "text" },
  ],
  title: [
    { name: "id", type: "uuid" },
    { name: "legacy_id", type: "text" },
    { name: "media_type", type: "text", pgType: "public.media_type" },
    { name: "title", type: "text" },
    { name: "original_title", type: "text" },
    { name: "normalized_title", type: "text" },
    { name: "plot", type: "text" },
    { name: "year", type: "integer" },
    { name: "release_date", type: "date" },
    { name: "duration", type: "text" },
    { name: "rating", type: "numeric" },
    { name: "poster_url", type: "text" },
    { name: "backdrop_url", type: "text" },
    { name: "is_featured", type: "boolean" },
    { name: "is_published", type: "boolean" },
    { name: "cast_members", type: "text" },
    { name: "director", type: "text" },
    { name: "writer", type: "text" },
    { name: "country_code", type: "text" },
    { name: "tmdb_id", type: "integer" },
    { name: "imdb_id", type: "text" },
  ],
  season: [
    { name: "id", type: "uuid" },
    { name: "title_id", type: "uuid" },
    { name: "season_number", type: "integer" },
    { name: "name", type: "text" },
    { name: "plot", type: "text" },
    { name: "poster_url", type: "text" },
  ],
  episode: [
    { name: "id", type: "uuid" },
    { name: "season_id", type: "uuid" },
    { name: "episode_number", type: "integer" },
    { name: "title", type: "text" },
    { name: "plot", type: "text" },
    { name: "duration", type: "text" },
    { name: "still_url", type: "text" },
    { name: "release_date", type: "date" },
  ],
  source: [
    { name: "id", type: "uuid" },
    { name: "title_id", type: "uuid" },
    { name: "episode_id", type: "uuid" },
    { name: "language_id", type: "uuid" },
    { name: "name", type: "text" },
    { name: "url", type: "text" },
    { name: "order_index", type: "integer" },
    { name: "status", type: "text" },
    { name: "requires_webview", type: "boolean" },
    { name: "referer_url", type: "text" },
    { name: "origin_url", type: "text" },
    { name: "user_agent_profile", type: "text" },
  ],
};

function canonicalizeDecimal(val) {
  const parsed = Number(val);
  if (isNaN(parsed)) return null;
  return parsed.toString();
}

function canonicalizeDate(val) {
  if (val instanceof Date) return val.toISOString().split("T")[0];
  if (typeof val === "string") return val.substring(0, 10);
  return val;
}

function canonicalizeJson(val) {
  if (typeof val === "string") {
    try {
      val = JSON.parse(val);
    } catch (e) {
      return val;
    }
  }
  function sortKeys(obj) {
    if (Array.isArray(obj)) return obj.map(sortKeys);
    if (obj !== null && typeof obj === "object") {
      return Object.keys(obj)
        .sort()
        .reduce((res, key) => {
          res[key] = sortKeys(obj[key]);
          return res;
        }, {});
    }
    return obj;
  }
  return JSON.stringify(sortKeys(val));
}

function normalizeData(val, type) {
  if (val === undefined || val === null || val === "") return null;
  if (type === "numeric") return canonicalizeDecimal(val);
  if (type === "date") return canonicalizeDate(val);
  if (type === "jsonb" || type === "json") return canonicalizeJson(val);
  if (type.includes("[]"))
    return Array.isArray(val) ? val.map(String).join(",") : String(val);
  if (type === "integer") return parseInt(val, 10);
  if (type === "boolean") return !!val;
  return String(val);
}

function normalizeRec(r, typeName) {
  const norm = {};
  for (const def of fieldsDef[typeName])
    norm[def.name] = normalizeData(r[def.name], def.type);
  return norm;
}

function validatePlanStructure(plan) {
  if (!plan || plan.version !== 1 || plan.namespace !== NAMESPACE) return false;
  if (plan.schemaMigration !== SCHEMA_MIGRATION) return false;
  if (!plan.catalogSha256 || !plan.schemaSha256 || !plan.planSha256)
    return false;

  const clone = JSON.parse(JSON.stringify(plan));
  delete clone.planSha256;
  const computedHash = crypto
    .createHash("sha256")
    .update(JSON.stringify(clone))
    .digest("hex");
  if (computedHash !== plan.planSha256) return false;

  if (plan.operations.length !== 1970) return false;

  const uuidSet = new Set();
  for (const op of plan.operations) {
    if (uuidSet.has(op.record.id)) return false;
    uuidSet.add(op.record.id);
  }

  return true;
}

async function runBootstrap(client, plan, mode) {
  let result = {
    code: 0,
    ready: 0,
    alreadyPresent: 0,
    conflict: 0,
    errors: [],
  };
  let txOpen = false;

  try {
    if (mode === "preflight") {
      await client.query("BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY");
    } else {
      await client.query("BEGIN ISOLATION LEVEL SERIALIZABLE");
      await client.query("SET LOCAL statement_timeout = 60000");
      await client.query("SET LOCAL lock_timeout = 10000");

      const lockRes = await client.query(
        "SELECT pg_try_advisory_xact_lock(hashtextextended($1, 0)) AS locked",
        [ADVISORY_LOCK_KEY],
      );
      if (!lockRes.rows[0].locked) {
        result.errors.push(
          "Concurrent execution rejected: could not acquire advisory lock",
        );
        result.code = 4;
        await client.query("ROLLBACK");
        return result;
      }
    }
    txOpen = true;

    // 1. Verify schema
    const migRes = await client.query(
      "SELECT version FROM supabase_migrations.schema_migrations WHERE version = '20260910165527'",
    );
    if (migRes.rowCount === 0) {
      result.errors.push("Migration 20260910165527 not applied");
      result.code = 3;
      await client.query("ROLLBACK");
      return result;
    }

    // 2. Verify metadata singleton
    const metaCheck = await client.query(
      "SELECT COUNT(*) as c FROM catalog_sync_metadata",
    );
    if (metaCheck.rowCount === 0 || parseInt(metaCheck.rows[0].c, 10) !== 1) {
      result.errors.push(
        "catalog_sync_metadata must contain exactly one singleton row",
      );
      result.code = 3;
      await client.query("ROLLBACK");
      return result;
    }

    // 3. Initial audit counts
    const initAuditQ =
      "SELECT latest_revision FROM catalog_sync_metadata WHERE id = 1" +
      (mode !== "preflight" ? " FOR UPDATE" : "");
    const initAudit = await client.query(initAuditQ);
    const initialLatestRevision = parseInt(
      initAudit.rows[0].latest_revision,
      10,
    );

    const initChangesCount = await client.query(
      "SELECT COUNT(*) as c FROM catalog_changes",
    );
    const initialChanges = parseInt(initChangesCount.rows[0].c, 10);

    const opsByEntity = {
      language: [],
      title: [],
      season: [],
      episode: [],
      source: [],
    };
    for (const op of plan.operations)
      opsByEntity[op.entityType].push(op.record);

    const order = ["language", "title", "season", "episode", "source"];
    let totalInsertedCount = 0;

    for (const entity of order) {
      const records = opsByEntity[entity];
      if (records.length === 0) continue;

      const ids = records.map((r) => r.id);
      const cols = fieldsDef[entity].map((d) => d.name).join(", ");
      const q = `SELECT ${cols} FROM ${entity}s WHERE id = ANY($1::uuid[])`;

      const existingRes = await client.query(q, [ids]);
      const existingMap = new Map();
      for (const r of existingRes.rows)
        existingMap.set(r.id, normalizeRec(r, entity));

      const toInsert = [];
      for (const r of records) {
        const normRec = normalizeRec(r, entity);
        if (existingMap.has(r.id)) {
          const ex = existingMap.get(r.id);
          if (JSON.stringify(normRec) === JSON.stringify(ex)) {
            result.alreadyPresent++;
          } else {
            result.conflict++;
            result.errors.push(`Conflict in ${entity} ${r.id}`);
            result.code = 3;
          }
        } else {
          result.ready++;
          toInsert.push(normRec);
        }
      }

      if (mode !== "preflight" && toInsert.length > 0 && result.code !== 3) {
        const jParams = JSON.stringify(toInsert);
        const typeDefs = fieldsDef[entity]
          .map((d) => `${d.name} ${d.type}`)
          .join(", ");
        const projCols = fieldsDef[entity]
          .map((d) => (d.pgType ? `x.${d.name}::${d.pgType}` : `x.${d.name}`))
          .join(", ");

        const iQ = `INSERT INTO ${entity}s (${cols}) SELECT ${projCols} FROM jsonb_to_recordset($1::jsonb) AS x(${typeDefs})`;
        await client.query(iQ, [jParams]);

        totalInsertedCount += toInsert.length;
      }
    }

    if (result.conflict > 0 || result.errors.length > 0) {
      await client.query("ROLLBACK");
      result.code = 3;
      return result;
    }

    if (mode === "preflight") {
      await client.query("ROLLBACK");
      if (result.ready > 0) result.code = 2;
      return result;
    }

    // 4. Audit verification
    const finalAudit = await client.query(
      "SELECT latest_revision FROM catalog_sync_metadata WHERE id = 1",
    );
    const finalLatestRevision = parseInt(
      finalAudit.rows[0].latest_revision,
      10,
    );

    if (finalLatestRevision - initialLatestRevision !== totalInsertedCount) {
      result.errors.push(
        `Audit delta incorrect on metadata. Expected ${totalInsertedCount}, got ${finalLatestRevision - initialLatestRevision}`,
      );
      result.code = 3;
      await client.query("ROLLBACK");
      return result;
    }

    const finalChangesCount = await client.query(
      "SELECT COUNT(*) as c FROM catalog_changes",
    );
    const finalChanges = parseInt(finalChangesCount.rows[0].c, 10);

    if (finalChanges - initialChanges !== totalInsertedCount) {
      result.errors.push(
        `Audit delta incorrect on catalog_changes rows. Expected ${totalInsertedCount}, got ${finalChanges - initialChanges}`,
      );
      result.code = 3;
      await client.query("ROLLBACK");
      return result;
    }

    const maxRevCheck = await client.query(
      "SELECT MAX(revision) as m FROM catalog_changes",
    );
    const maxRev = maxRevCheck.rows[0].m
      ? parseInt(maxRevCheck.rows[0].m, 10)
      : 0;
    if (maxRev !== finalLatestRevision && maxRev !== 0) {
      result.errors.push(
        `Max revision gap. max(revision)=${maxRev}, latest_revision=${finalLatestRevision}`,
      );
      result.code = 3;
      await client.query("ROLLBACK");
      return result;
    }

    if (mode === "validate") {
      await client.query("ROLLBACK");
      result.code = 0;
    } else {
      await client.query("COMMIT");
      result.code = 0;
    }
  } catch (e) {
    if (txOpen)
      try {
        await client.query("ROLLBACK");
      } catch (err) {}
    let cleanMsg = e.message
      .replace(/https?:\/\/[^\s]+/g, "[REDACTED_URL]")
      .replace(/:[^\s]+@/g, ":[REDACTED_AUTH]@");
    if (
      e.code === "40001" ||
      e.code === "55P03" ||
      e.code === "57014" ||
      e.code === "40P01"
    ) {
      result.code = 4;
      result.errors.push("Transient PostgreSQL error: " + cleanMsg);
    } else {
      result.code = 3;
      result.errors.push("Error: " + cleanMsg);
    }
  }

  return result;
}

async function main() {
  const args = process.argv.slice(2);

  const modesCount = [
    "--preflight",
    "--apply",
    "--validate-transaction",
  ].filter((m) => args.includes(m)).length;
  if (modesCount !== 1) {
    console.error(
      "Exactly ONE mode required: --preflight, --apply or --validate-transaction",
    );
    process.exit(1);
  }

  let mode = "preflight";
  if (args.includes("--apply")) mode = "apply";
  if (args.includes("--validate-transaction")) mode = "validate";

  const planIndex = args.indexOf("--plan");
  if (planIndex === -1 || !args[planIndex + 1]) {
    console.error("Missing --plan <path>");
    process.exit(1);
  }
  const planPath = args[planIndex + 1];

  const shaIndex = args.indexOf("--expected-sha256");
  if (shaIndex === -1 || !args[shaIndex + 1]) {
    console.error("Missing --expected-sha256");
    process.exit(1);
  }
  const expectedSha = args[shaIndex + 1];

  const dbUrl = process.env.SUPABASE_DB_URL;
  if (!dbUrl) {
    console.error("Missing SUPABASE_DB_URL environment variable");
    process.exit(1);
  }

  if (mode === "apply" && process.env.CONFIRM_PRODUCTION_APPLY !== "true") {
    console.error(
      "Missing explicit CONFIRM_PRODUCTION_APPLY=true variable for apply mode",
    );
    process.exit(1);
  }

  if (
    mode === "validate" &&
    process.env.CONFIRM_VALIDATE_TRANSACTION !== "true"
  ) {
    console.error(
      "Missing explicit CONFIRM_VALIDATE_TRANSACTION=true variable for validate mode",
    );
    process.exit(1);
  }

  if (!fs.existsSync(planPath)) {
    console.error("Plan file not found");
    process.exit(3);
  }

  let plan;
  try {
    plan = JSON.parse(fs.readFileSync(planPath, "utf8"));
  } catch (e) {
    console.error("Invalid plan JSON");
    process.exit(3);
  }

  if (!validatePlanStructure(plan)) {
    console.error("Plan validation failed");
    process.exit(3);
  }

  if (expectedSha !== plan.planSha256) {
    console.error("Expected SHA-256 does not match plan");
    process.exit(3);
  }

  const client = new Client({ connectionString: dbUrl });
  try {
    await client.connect();
  } catch (e) {
    console.error("Connection failed");
    process.exit(4);
  }

  let clientEnded = false;
  const safeEnd = async () => {
    if (!clientEnded) {
      clientEnded = true;
      try {
        await client.end();
      } catch (e) {}
    }
  };

  process.on("SIGINT", async () => {
    await safeEnd();
    process.exit(130);
  });
  process.on("SIGTERM", async () => {
    await safeEnd();
    process.exit(143);
  });

  const result = await runBootstrap(client, plan, mode);
  await safeEnd();

  console.log("--- POSTGRESQL RUNNER REPORT ---");
  console.log(`Mode: ${mode}`);
  console.log(`Code: ${result.code}`);
  console.log(`Ready: ${result.ready}`);
  console.log(`Already Present: ${result.alreadyPresent}`);
  console.log(`Conflict: ${result.conflict}`);
  if (result.errors.length > 0) {
    console.log("Errors:");
    for (const e of result.errors) console.log(`  - ${e}`);
  }

  process.exit(result.code);
}

module.exports = { runBootstrap, validatePlanStructure, normalizeData };

if (require.main === module) {
  main().catch((err) => {
    let cleanMsg = err.message
      .replace(/https?:\/\/[^\s]+/g, "[REDACTED_URL]")
      .replace(/:[^\s]+@/g, ":[REDACTED_AUTH]@");
    console.error("Fatal:", cleanMsg);
    process.exit(3);
  });
}
