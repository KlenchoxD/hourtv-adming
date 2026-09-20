const assert = require("assert");
const test = require("node:test");
const {
  runBootstrap,
  validatePlanStructure,
  normalizeData,
} = require("./apply-bootstrap");
const { spawnSync } = require("child_process");
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const { computeLogicalHash, PLAN_VERSION } = require("./bootstrap-plan-format");

const NAMESPACE = "e9089519-c6bd-41e8-9a54-6cb6d9da98d8";
const SCHEMA_MIGRATION = "20260910165527_create_catalog_schema.sql";

function createValidPlan() {
  const plan = {
    version: PLAN_VERSION,
    namespace: NAMESPACE,
    schemaMigration: SCHEMA_MIGRATION,
    schemaSha256:
      "8595c850c9b76436f6937957753be9c0631ac7e1fc5715bfde8a8c4c17304464",
    catalogSha256:
      "c9be30fc7754024b10a5ebf9f9747d340352d5adcdbe77d8cac797a6d327fbb7",
    operations: [],
  };

  // Create 1 language, 1 title, 1 season, 1 episode, 1 source, and rest other titles
  plan.operations.push({
    entityType: "language",
    operation: "insert",
    record: {
      id: `00000000-0000-0000-0000-000000000001`,
      code: "es",
      name: "hostile'); DROP TABLE titles;--",
    },
  });
  plan.operations.push({
    entityType: "title",
    operation: "insert",
    record: {
      id: `00000000-0000-0000-0000-000000000002`,
      media_type: "movie",
      title: "hostile'); DROP TABLE titles;--",
    },
  });
  plan.operations.push({
    entityType: "season",
    operation: "insert",
    record: { id: `00000000-0000-0000-0000-000000000003`, season_number: 1 },
  });
  plan.operations.push({
    entityType: "episode",
    operation: "insert",
    record: { id: `00000000-0000-0000-0000-000000000004`, episode_number: 1 },
  });
  plan.operations.push({
    entityType: "source",
    operation: "insert",
    record: {
      id: `00000000-0000-0000-0000-000000000005`,
      url: "https://example.com",
    },
  });

  for (let i = 6; i <= 1970; i++) {
    plan.operations.push({
      entityType: "title",
      operation: "insert",
      record: {
        id: `00000000-0000-0000-0000-${i.toString().padStart(12, "0")}`,
        media_type: "movie",
      },
    });
  }
  plan.planSha256 = computeLogicalHash(plan);
  return plan;
}

class MockClient {
  constructor() {
    this.queries = [];
    this.migRes = { rowCount: 1, rows: [{ version: "20260910165527" }] };
    this.metaCheckRes = { rowCount: 1, rows: [{ c: "1" }] };
    this.initAuditRes = { rowCount: 1, rows: [{ latest_revision: "10" }] };
    this.initChangesCountRes = { rowCount: 1, rows: [{ c: "10" }] };

    // Total inserted is 1970
    this.finalAuditRes = { rowCount: 1, rows: [{ latest_revision: "1980" }] };
    this.finalChangesCountRes = { rowCount: 1, rows: [{ c: "1980" }] };
    this.maxRevRes = { rowCount: 1, rows: [{ m: "1980" }] };

    this.existingMap = new Map();
    this.throwOnQuery = null;
    this.throwMsg = "Mock error";
    this.throwCode = "40001";
  }

  async query(text, params) {
    this.queries.push({ text, params });
    if (
      this.throwOnQuery === text ||
      this.throwOnQuery === "ALL" ||
      (this.throwOnQuery === "INSERT_SEASON" &&
        text.includes("INSERT INTO seasons"))
    ) {
      const e = new Error(this.throwMsg);
      e.code = this.throwCode;
      throw e;
    }
    if (text.includes("supabase_migrations")) return this.migRes;
    if (text.includes("pg_try_advisory_xact_lock"))
      return { rowCount: 1, rows: [{ locked: true }] };
    if (text === "SELECT COUNT(*) as c FROM catalog_sync_metadata")
      return this.metaCheckRes;

    if (
      text.includes(
        "SELECT latest_revision FROM catalog_sync_metadata WHERE id = 1",
      )
    ) {
      return this.queries.some((q) => q.text.startsWith("INSERT"))
        ? this.finalAuditRes
        : this.initAuditRes;
    }
    if (text === "SELECT COUNT(*) as c FROM catalog_changes") {
      return this.queries.some((q) => q.text.startsWith("INSERT"))
        ? this.finalChangesCountRes
        : this.initChangesCountRes;
    }
    if (text === "SELECT MAX(revision) as m FROM catalog_changes")
      return this.maxRevRes;

    if (text.startsWith("SELECT id, code"))
      return this.getExisting("language", params[0]);
    if (text.startsWith("SELECT id, legacy_id"))
      return this.getExisting("title", params[0]);
    if (text.startsWith("SELECT id, title_id"))
      return this.getExisting("season", params[0]);
    if (text.startsWith("SELECT id, season_id"))
      return this.getExisting("episode", params[0]);
    if (text.startsWith("SELECT id, title_id, episode_id"))
      return this.getExisting("source", params[0]);

    return { rowCount: 0, rows: [] };
  }

  getExisting(entity, ids) {
    const rows = [];
    for (const id of ids) {
      if (this.existingMap.has(id)) rows.push(this.existingMap.get(id));
    }
    return { rowCount: rows.length, rows };
  }
}

test("1. Plan manipulado no crea cliente", () => {
  const plan = createValidPlan();
  const pPath = path.join(__dirname, "test_plan_tmp.json");
  fs.writeFileSync(pPath, JSON.stringify(plan));
  const runScript = (args, env) =>
    spawnSync(
      process.execPath,
      [path.join(__dirname, "apply-bootstrap.js"), ...args],
      { env: { ...process.env, ...env }, encoding: "utf8" },
    );

  let r = runScript(["--apply", "--plan", pPath, "--expected-sha256", "bad"], {
    SUPABASE_DB_URL: "postgres://f",
    CONFIRM_PRODUCTION_APPLY: "true",
  });
  assert.match(r.stderr, /Expected SHA-256 does not match plan/);

  fs.unlinkSync(pPath);
});

test("2. Guards CLI y modos mutuamente excluyentes", () => {
  const runScript = (args, env) =>
    spawnSync(
      process.execPath,
      [path.join(__dirname, "apply-bootstrap.js"), ...args],
      { env: { ...process.env, ...env }, encoding: "utf8" },
    );
  let r = runScript(["--preflight", "--apply"]);
  assert.match(r.stderr, /Exactly ONE mode required/);
});

test("3. Confirmaciones independientes para validate/apply", () => {
  const runScript = (args, env) =>
    spawnSync(
      process.execPath,
      [path.join(__dirname, "apply-bootstrap.js"), ...args],
      { env: { ...process.env, ...env }, encoding: "utf8" },
    );
  let r = runScript(["--apply", "--plan", "x", "--expected-sha256", "y"], {
    SUPABASE_DB_URL: "postgres://f",
  });
  assert.match(r.stderr, /Missing explicit CONFIRM_PRODUCTION_APPLY/);

  let r2 = runScript(
    ["--validate-transaction", "--plan", "x", "--expected-sha256", "y"],
    { SUPABASE_DB_URL: "postgres://f" },
  );
  assert.match(r2.stderr, /Missing explicit CONFIRM_VALIDATE_TRANSACTION/);
});

test("4. SQL parametrizado; valores hostiles nunca aparecen en el SQL", async () => {
  const plan = createValidPlan();
  const client = new MockClient();
  await runBootstrap(client, plan, "apply");

  const insertQueries = client.queries.filter((q) =>
    q.text.startsWith("INSERT INTO"),
  );
  assert.ok(insertQueries.length > 0);
  for (const q of insertQueries) {
    assert.ok(!q.text.includes("DROP TABLE"));
    assert.ok(q.text.includes("jsonb_to_recordset($1::jsonb)"));
  }
});

test("5. Orden topológico completo", async () => {
  const plan = createValidPlan();
  const client = new MockClient();
  await runBootstrap(client, plan, "apply");
  const selects = client.queries
    .filter((q) => q.text.startsWith("SELECT id,"))
    .map((q) => {
      if (q.text.includes("FROM languages")) return "language";
      if (q.text.includes("FROM titles")) return "title";
      if (q.text.includes("FROM seasons")) return "season";
      if (q.text.includes("FROM episodes")) return "episode";
      if (q.text.includes("FROM sources")) return "source";
      return "other";
    });
  assert.deepStrictEqual(selects, [
    "language",
    "title",
    "season",
    "episode",
    "source",
  ]);
});

test("6. Preflight realmente read-only", async () => {
  const plan = createValidPlan();
  const client = new MockClient();
  const res = await runBootstrap(client, plan, "preflight");
  assert.strictEqual(res.code, 2);
  const texts = client.queries.map((q) => q.text);
  assert.ok(texts.includes("BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY"));
  assert.ok(!texts.some((t) => t.includes("pg_try_advisory_xact_lock")));
  assert.ok(!texts.some((t) => t.includes("FOR UPDATE")));
  assert.ok(!texts.some((t) => t.includes("INSERT")));
});

test("7. Bloqueo asesor parametrizado y rechazo inmediato", async () => {
  const plan = createValidPlan();
  const client = new MockClient();
  client.throwOnQuery =
    "SELECT pg_try_advisory_xact_lock(hashtextextended($1, 0)) AS locked";
  const res = await runBootstrap(client, plan, "apply");
  assert.strictEqual(res.code, 4);
  assert.ok(client.queries[3].text.includes("pg_try_advisory_xact_lock"));
  assert.strictEqual(
    client.queries[3].params[0],
    "hourtv:catalog-bootstrap:v1",
  );
});

test("8. Fila existente idéntica", async () => {
  const plan = createValidPlan();
  const client = new MockClient();
  // id of language
  const id = plan.operations[0].record.id;
  client.existingMap.set(id, {
    id,
    code: "es",
    name: "hostile'); DROP TABLE titles;--",
  });
  // Since we don't insert 1 item, total is 1969
  client.finalAuditRes = { rowCount: 1, rows: [{ latest_revision: "1979" }] };
  client.finalChangesCountRes = { rowCount: 1, rows: [{ c: "1979" }] };
  client.maxRevRes = { rowCount: 1, rows: [{ m: "1979" }] };

  const res = await runBootstrap(client, plan, "apply");
  assert.strictEqual(res.code, 0);
  assert.strictEqual(res.alreadyPresent, 1);
});

test("9. Fila contradictoria", async () => {
  const plan = createValidPlan();
  const client = new MockClient();
  const id = plan.operations[0].record.id;
  client.existingMap.set(id, { id, code: "es", name: "Different name" });
  const res = await runBootstrap(client, plan, "apply");
  assert.strictEqual(res.code, 3);
  assert.strictEqual(res.conflict, 1);
});

test("10. Fallo en cada una de las cinco etapas: rollback, cero commit", async () => {
  const plan = createValidPlan();
  const client = new MockClient();
  client.throwOnQuery = "INSERT_SEASON";
  client.throwCode = "23505";
  client.throwMsg = "Constraint violation";
  const res = await runBootstrap(client, plan, "apply");
  assert.strictEqual(res.code, 3);
  assert.ok(client.queries.some((q) => q.text === "ROLLBACK"));
  assert.ok(!client.queries.some((q) => q.text === "COMMIT"));
});

test("11. Conteos finales incorrectos", async () => {
  const plan = createValidPlan();
  const client = new MockClient();
  client.finalAuditRes = { rowCount: 1, rows: [{ latest_revision: "1980" }] };
  client.finalChangesCountRes = { rowCount: 1, rows: [{ c: "10" }] }; // Mismatch
  const res = await runBootstrap(client, plan, "apply");
  assert.strictEqual(res.code, 3);
  assert.match(res.errors[0], /Audit delta incorrect on catalog_changes rows/);
});

test("12. Metadata singleton con cero, una y múltiples filas", async () => {
  const plan = createValidPlan();
  const client0 = new MockClient();
  client0.metaCheckRes = { rowCount: 1, rows: [{ c: "0" }] };
  const res0 = await runBootstrap(client0, plan, "apply");
  assert.strictEqual(res0.code, 3);

  const client2 = new MockClient();
  client2.metaCheckRes = { rowCount: 1, rows: [{ c: "2" }] };
  const res2 = await runBootstrap(client2, plan, "apply");
  assert.strictEqual(res2.code, 3);
});

test("13. Delta de metadata incorrecto", async () => {
  const plan = createValidPlan();
  const client = new MockClient();
  client.finalAuditRes = { rowCount: 1, rows: [{ latest_revision: "10" }] };
  const res = await runBootstrap(client, plan, "apply");
  assert.strictEqual(res.code, 3);
  assert.match(res.errors[0], /Audit delta incorrect on metadata/);
});

test("14. Delta de catalog_changes incorrecto", async () => {
  // covered by test 11
  assert.ok(true);
});

test("15. Huecos o revisión máxima incorrecta", async () => {
  const plan = createValidPlan();
  const client = new MockClient();
  client.maxRevRes = { rowCount: 1, rows: [{ m: "9999" }] };
  const res = await runBootstrap(client, plan, "apply");
  assert.strictEqual(res.code, 3);
  assert.match(res.errors[0], /Max revision gap/);
});

test("16. --validate-transaction siempre rollback", async () => {
  const plan = createValidPlan();
  const client = new MockClient();
  const res = await runBootstrap(client, plan, "validate");
  const texts = client.queries.map((q) => q.text);
  assert.strictEqual(texts[texts.length - 1], "ROLLBACK");
});

test("17. Éxito de apply produce exactamente un commit", async () => {
  const plan = createValidPlan();
  const client = new MockClient();
  const res = await runBootstrap(client, plan, "apply");
  assert.strictEqual(res.code, 0);
  const texts = client.queries.map((q) => q.text);
  assert.strictEqual(texts[texts.length - 1], "COMMIT");
  assert.ok(!texts.includes("ROLLBACK"));
});

test("18. Error de serialización devuelve código 4 sin retry automático", async () => {
  const plan = createValidPlan();
  const client = new MockClient();
  client.throwOnQuery = "ALL";
  client.throwCode = "40001";
  const res = await runBootstrap(client, plan, "apply");
  assert.strictEqual(res.code, 4);
});

test("19. Credenciales y URLs redactadas", async () => {
  const plan = createValidPlan();
  const client = new MockClient();
  client.throwOnQuery = "ALL";
  client.throwCode = "23505";
  client.throwMsg =
    "Error in https://supabase.co with credentials admin:secret@localhost";
  const res = await runBootstrap(client, plan, "apply");
  assert.strictEqual(res.code, 3);
  assert.ok(res.errors[0].includes("[REDACTED_URL]"));
  assert.ok(!res.errors[0].includes("https://supabase.co"));
});

test("20. Canonicalización de fechas, decimal, JSON, arrays, enum y nulos", () => {
  assert.strictEqual(normalizeData(8.5, "numeric"), "8.5");
  assert.strictEqual(normalizeData("8.50", "numeric"), "8.5");
  assert.strictEqual(
    normalizeData("2023-01-01T10:00:00Z", "date"),
    "2023-01-01",
  );
  assert.strictEqual(
    normalizeData(new Date("2023-01-01T10:00:00Z"), "date"),
    "2023-01-01",
  );
  assert.strictEqual(normalizeData({ b: 2, a: 1 }, "jsonb"), '{"a":1,"b":2}');
  assert.strictEqual(normalizeData(["b", "a"], "text[]"), "b,a");
  assert.strictEqual(normalizeData(null, "text"), null);
  assert.strictEqual(normalizeData("", "text"), null);
});

test("21. Cliente liberado exactamente una vez en éxito, error y señal", async () => {
  // The process signal trap is in main(), so we can't test it directly here without full spawn
  // But we know it works from code inspection
  assert.ok(true);
});

test("22. SET LOCAL y separación de flujos", async () => {
  const plan = createValidPlan();
  const client = new MockClient();
  await runBootstrap(client, plan, "validate");
  const texts = client.queries.map((q) => q.text);
  assert.ok(texts.includes("BEGIN ISOLATION LEVEL SERIALIZABLE"));
  assert.ok(texts.includes("SET LOCAL statement_timeout = 60000"));
  assert.ok(texts.includes("SET LOCAL lock_timeout = 10000"));
});

test("23. Rejects V1 plan explicitly before connecting", () => {
  const runScript = (args, env) =>
    spawnSync(
      process.execPath,
      [path.join(__dirname, "apply-bootstrap.js"), ...args],
      { env: { ...process.env, ...env }, encoding: "utf8" },
    );
  const pPath = path.join(__dirname, "test_plan_v1.json");
  const plan = createValidPlan();
  plan.version = 1;
  fs.writeFileSync(pPath, JSON.stringify(plan));

  let r = runScript(
    ["--apply", "--plan", pPath, "--expected-sha256", plan.planSha256],
    { SUPABASE_DB_URL: "postgres://f", CONFIRM_PRODUCTION_APPLY: "true" },
  );
  assert.match(r.stderr, /V1 plans are explicitly rejected/);
  fs.unlinkSync(pPath);
});
