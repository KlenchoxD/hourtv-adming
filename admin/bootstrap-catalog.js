const fs = require("fs");
const crypto = require("crypto");
const path = require("path");
const { PLAN_VERSION, computeLogicalHash } = require("./bootstrap-plan-format");

const NAMESPACE = "e9089519-c6bd-41e8-9a54-6cb6d9da98d8";
const SCHEMA_MIGRATION = "20260910165527_create_catalog_schema.sql";

function uuidToBytes(uuidStr) {
  const hex = uuidStr.replace(/-/g, "");
  return Buffer.from(hex, "hex");
}

function bytesToUuid(buf) {
  const hex = buf.toString("hex");
  return [
    hex.substring(0, 8),
    hex.substring(8, 12),
    hex.substring(12, 16),
    hex.substring(16, 20),
    hex.substring(20, 32),
  ].join("-");
}

function uuidv5(name, namespaceUuid) {
  const nsBytes = uuidToBytes(namespaceUuid);
  const nameBytes = Buffer.from(name, "utf8");
  const hash = crypto
    .createHash("sha1")
    .update(Buffer.concat([nsBytes, nameBytes]))
    .digest();

  const bytes = Buffer.alloc(16);
  hash.copy(bytes, 0, 0, 16);

  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  return bytesToUuid(bytes);
}

function isUUID(uuid) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[45][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
    uuid,
  );
}

function isValidUrl(url) {
  if (typeof url !== "string") return false;
  if (!/^https:\/\//i.test(url)) return false;
  if (/^(https:\/\/)?([^/@]+@)/i.test(url)) return false;
  if (/^(https:\/\/)?(localhost|127\.|0\.0\.0\.0|\[::1\])/i.test(url))
    return false;
  if (
    /^(https:\/\/)?(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.|169\.254\.|\[fe80:)/i.test(
      url,
    )
  )
    return false;
  if (/(\?|&|#)(token|api_key|secret|auth|cookie|jwt)=/i.test(url))
    return false;
  return true;
}

const LANG_MAP = {
  Español: { code: "es", name: "Español" },
  "Español Latino": { code: "es-lat", name: "Español Latino" },
  Subtitulado: { code: "sub", name: "Subtitulado" },
  "Idioma sin identificar": { code: "und", name: "Idioma sin identificar" },
  Inglés: { code: "en", name: "Inglés" },
};

function writeAtomic(filePath, dataStr) {
  const tmpPath = filePath + ".tmp";
  fs.writeFileSync(tmpPath, dataStr, "utf8");
  fs.renameSync(tmpPath, filePath);
}

function generateBootstrapPlan(
  catalogPath,
  existingPlanPath = null,
  snapshotPath = null,
  overrideSchemaPath = null,
) {
  const schemaPath =
    overrideSchemaPath ||
    path.resolve(__dirname, "../supabase/migrations", SCHEMA_MIGRATION);
  if (!fs.existsSync(schemaPath)) {
    return { error: "Schema migration file not found", code: 3 };
  }
  const schemaRaw = fs.readFileSync(schemaPath, "utf8");
  const schemaSha256 = crypto
    .createHash("sha256")
    .update(schemaRaw)
    .digest("hex");

  const catalogRaw = fs.readFileSync(catalogPath, "utf8");
  const catalogSha256 = crypto
    .createHash("sha256")
    .update(catalogRaw)
    .digest("hex");
  const catalog = JSON.parse(catalogRaw.replace(/^\uFEFF/, ""));

  let existingPlan = null;
  if (existingPlanPath && fs.existsSync(existingPlanPath)) {
    try {
      existingPlan = JSON.parse(fs.readFileSync(existingPlanPath, "utf8"));

      // Check signature
      if (existingPlan.schemaMigration !== SCHEMA_MIGRATION) {
        return { error: "Incompatible schema version", code: 3 };
      }
      if (
        existingPlan.schemaSha256 &&
        existingPlan.schemaSha256 !== schemaSha256
      ) {
        return {
          error: "Schema file content changed after plan generation",
          code: 3,
        };
      }

      // Check catalog hash
      if (
        existingPlan.catalogSha256 &&
        existingPlan.catalogSha256 !== catalogSha256
      ) {
        return { error: "Catalog changed after plan generation", code: 3 };
      }

      // Check plan corruption
      const oldHash = existingPlan.planSha256;
      const computedOldHash = computeLogicalHash(existingPlan);
      if (oldHash !== computedOldHash) {
        return { error: "Plan corrupted or manipulated", code: 3 };
      }
      // restore hash if needed
      existingPlan.planSha256 = oldHash;
    } catch (e) {
      return { error: "Invalid plan structure", code: 3 };
    }
  }

  let snapshotOps = new Map();
  let isAuthoritative = false;
  if (snapshotPath && fs.existsSync(snapshotPath)) {
    const snapData = JSON.parse(fs.readFileSync(snapshotPath, "utf8"));
    if (snapData.authoritative === true) {
      isAuthoritative = true;
      if (Array.isArray(snapData.records)) {
        for (const r of snapData.records) {
          snapshotOps.set(r.id, r);
        }
      }
    }
  }

  const plan = {
    version: PLAN_VERSION,
    namespace: NAMESPACE,
    catalogCommit: null,
    catalogSha256,
    schemaMigration: SCHEMA_MIGRATION,
    schemaSha256,
    counts: { languages: 0, titles: 0, seasons: 0, episodes: 0, sources: 0 },
    stats: {
      urlsInspected: 0,
      urlsValid: 0,
      urlsInvalid: 0,
      ready: 0,
      invalid: 0,
      duplicate: 0,
      missingParent: 0,
      alreadyPresent: 0,
      conflict: 0,
    },
    planUnchanged: false,
    expectedAuditChanges: { titles: 0, seasons: 0, episodes: 0, sources: 0 },
    operations: [],
  };

  const seenIds = new Set();
  const identityHashes = new Set();

  const trackIdentity = (uuid, identityStr) => {
    if (!isUUID(uuid)) {
      plan.stats.invalid++;
      return false;
    }
    if (seenIds.has(uuid) || identityHashes.has(identityStr)) {
      plan.stats.duplicate++;
      return false;
    }
    seenIds.add(uuid);
    identityHashes.add(identityStr);
    return true;
  };

  const addOp = (entityType, record, deps = []) => {
    plan.counts[entityType + "s"]++;
    if (entityType !== "language") {
      plan.expectedAuditChanges[entityType + "s"]++;
    }

    let isInvalid = false;
    for (const d of deps) {
      if (!seenIds.has(d)) {
        plan.stats.missingParent++;
        return;
      }
    }

    if (entityType === "source") {
      plan.stats.urlsInspected++;
      if (!isValidUrl(record.url)) {
        plan.stats.urlsInvalid++;
        isInvalid = true;
      } else {
        plan.stats.urlsValid++;
      }
    }

    if (isInvalid) {
      plan.stats.invalid++;
      return;
    }

    if (isAuthoritative) {
      const snapRec = snapshotOps.get(record.id);
      if (snapRec) {
        const isIdentical =
          JSON.stringify(snapRec.data) === JSON.stringify(record);
        if (isIdentical) {
          plan.stats.alreadyPresent++;
          plan.operations.push({
            entityType,
            operation: "alreadyPresent",
            record,
            deps,
          });
          return;
        } else {
          plan.stats.conflict++;
          plan.operations.push({
            entityType,
            operation: "conflict",
            record,
            deps,
          });
          return;
        }
      }
    }

    plan.stats.ready++;
    plan.operations.push({ entityType, operation: "insert", record, deps });
  };

  const languageMap = new Map();
  const processServerLang = (langRaw) => {
    let lData;
    if (!langRaw || langRaw === "Idioma sin identificar") {
      lData = LANG_MAP["Idioma sin identificar"];
    } else {
      lData = LANG_MAP[langRaw];
    }

    if (!lData) {
      plan.stats.invalid++;
      return null;
    }

    const identityStr = `lang:${lData.code}`;
    if (!languageMap.has(identityStr)) {
      const lId = uuidv5(identityStr, NAMESPACE);
      if (trackIdentity(lId, identityStr)) {
        languageMap.set(identityStr, lId);
        addOp("language", { id: lId, code: lData.code, name: lData.name });
      }
    }
    return languageMap.get(identityStr);
  };

  const parseNum = (v) => {
    const p = parseInt(v, 10);
    return isNaN(p) ? null : p;
  };

  if (Array.isArray(catalog.movies)) {
    for (const m of catalog.movies) {
      const legacyId = m.id || (m.tmdbId ? m.tmdbId.toString() : null);
      let titleId = null;
      if (!legacyId) {
        plan.stats.invalid++;
      } else {
        const identityStr = `title:movie:${legacyId}`;
        titleId = uuidv5(identityStr, NAMESPACE);
        if (trackIdentity(titleId, identityStr)) {
          const titleRec = {
            id: titleId,
            legacy_id: legacyId,
            media_type: "movie",
            title: m.title || "Unknown",
            original_title: null,
            normalized_title: (m.title || "unknown").toLowerCase(),
            plot: m.plot || null,
            year: parseNum(m.year),
            release_date: m.releaseDate ? m.releaseDate.substring(0, 10) : null,
            duration: m.duration || null,
            rating: m.rating ? parseFloat(m.rating) : null,
            poster_url: m.poster || null,
            backdrop_url: m.backdrop || null,
            is_featured: false,
            is_published: true,
            cast_members: m.cast || null,
            director: m.director || null,
            writer: m.writer || null,
            country_code: null,
            tmdb_id: parseNum(m.tmdbId),
            imdb_id: null,
          };
          addOp("title", titleRec);
        }
      }

      if (Array.isArray(m.servers)) {
        for (const srv of m.servers) {
          if (!srv.id) {
            plan.stats.invalid++;
            continue;
          }
          const identityStrSrc = `source:${srv.id}`;
          if (!trackIdentity(srv.id, identityStrSrc)) continue;

          const lId = processServerLang(srv.language);
          if (!lId) continue;

          const srcRec = {
            id: srv.id,
            title_id: titleId,
            episode_id: null,
            language_id: lId,
            name: srv.name || "Server",
            url: srv.url,
            order_index: 0,
            status: "active",
            requires_webview: false,
            referer_url: null,
            origin_url: null,
            user_agent_profile: null,
          };
          addOp("source", srcRec, [titleId, lId]);
        }
      }
    }
  }

  if (Array.isArray(catalog.series)) {
    for (const s of catalog.series) {
      const legacyId =
        s.id || (s.tmdbId ? s.tmdbId.toString() : null) || s.title;
      let titleId = null;
      if (!legacyId) {
        plan.stats.invalid++;
      } else {
        const identityStr = `title:series:${legacyId}`;
        titleId = uuidv5(identityStr, NAMESPACE);
        if (trackIdentity(titleId, identityStr)) {
          const titleRec = {
            id: titleId,
            legacy_id: legacyId,
            media_type: "series",
            title: s.title || "Unknown",
            original_title: null,
            normalized_title: (s.title || "unknown").toLowerCase(),
            plot: s.plot || null,
            year: parseNum(s.year),
            release_date: s.releaseDate ? s.releaseDate.substring(0, 10) : null,
            duration: s.duration || null,
            rating: s.rating ? parseFloat(s.rating) : null,
            poster_url: s.poster || null,
            backdrop_url: s.backdrop || null,
            is_featured: false,
            is_published: true,
            cast_members: s.cast || null,
            director: s.director || null,
            writer: s.writer || null,
            country_code: null,
            tmdb_id: parseNum(s.tmdbId),
            imdb_id: null,
          };
          addOp("title", titleRec);
        }
      }

      if (Array.isArray(s.seasons)) {
        for (const sea of s.seasons) {
          const sNum = parseNum(sea.number);
          let seasonId = null;

          if (sNum === null) {
            // Invalid season because number is invalid
            plan.stats.invalid++;
          } else {
            const identityStrSea = `season:${legacyId}:${sNum}`;
            seasonId = uuidv5(identityStrSea, NAMESPACE);
            if (trackIdentity(seasonId, identityStrSea)) {
              const seasonRec = {
                id: seasonId,
                title_id: titleId,
                season_number: sNum,
                name: sea.name || null,
                plot: sea.plot || null,
                poster_url: sea.poster || null,
              };
              addOp("season", seasonRec, [titleId]);
            }
          }

          if (Array.isArray(sea.episodes)) {
            for (const ep of sea.episodes) {
              const eNum = parseNum(ep.number);
              let episodeId = null;

              if (eNum === null || sNum === null) {
                plan.stats.invalid++;
              } else {
                const identityStrEp = `episode:${legacyId}:${sNum}:${eNum}`;
                episodeId = uuidv5(identityStrEp, NAMESPACE);
                if (trackIdentity(episodeId, identityStrEp)) {
                  const epRec = {
                    id: episodeId,
                    season_id: seasonId,
                    episode_number: eNum,
                    title: ep.title || `Episodio ${eNum}`,
                    plot: ep.plot || null,
                    duration: ep.duration || null,
                    still_url: ep.still_url || ep.still || null,
                    release_date: null,
                  };
                  addOp("episode", epRec, [seasonId]);
                }
              }

              if (Array.isArray(ep.servers)) {
                for (const srv of ep.servers) {
                  if (!srv.id) {
                    plan.stats.invalid++;
                    continue;
                  }
                  const identityStrSrc = `source:${srv.id}`;
                  if (!trackIdentity(srv.id, identityStrSrc)) continue;

                  const lId = processServerLang(srv.language);
                  if (!lId) continue;

                  const srcRec = {
                    id: srv.id,
                    title_id: null,
                    episode_id: episodeId,
                    language_id: lId,
                    name: srv.name || "Server",
                    url: srv.url,
                    order_index: 0,
                    status: "active",
                    requires_webview: false,
                    referer_url: null,
                    origin_url: null,
                    user_agent_profile: null,
                  };
                  addOp("source", srcRec, [episodeId, lId]);
                }
              }
            }
          }
        }
      }
    }
  }

  if (existingPlan && existingPlan.operations) {
    if (
      JSON.stringify(plan.operations) ===
      JSON.stringify(existingPlan.operations)
    ) {
      plan.planUnchanged = true;
    }
  }

  plan.planSha256 = computeLogicalHash(plan);

  let code = 0;
  if (
    plan.stats.invalid > 0 ||
    plan.stats.duplicate > 0 ||
    plan.stats.missingParent > 0 ||
    plan.stats.conflict > 0
  ) {
    code = 3;
  } else if (plan.stats.ready > 0 || plan.stats.alreadyPresent > 0) {
    code = 2; // Pending apply or identical re-entry
  }

  return {
    plan,
    planStr: JSON.stringify(plan, null, 2),
    code,
    catalogSha256,
    schemaSha256,
  };
}

module.exports = {
  generateBootstrapPlan,
  writeAtomic,
  isUUID,
  uuidv5,
  NAMESPACE,
  SCHEMA_MIGRATION,
  isValidUrl,
};

if (require.main === module) {
  const args = process.argv.slice(2);

  if (args.includes("--help")) {
    console.log(
      "Usage: node bootstrap-catalog.js --catalog <ruta> [--write-plan <ruta>] [--dry-run] [--snapshot <ruta>]",
    );
    process.exit(0);
  }

  const isDryRun = args.includes("--dry-run");
  const isWritePlan = args.includes("--write-plan");

  const catalogIndex = args.indexOf("--catalog");
  if (catalogIndex === -1 || !args[catalogIndex + 1]) {
    console.error("Error: Missing --catalog <ruta>");
    process.exit(1);
  }

  const catalogPath = path.resolve(process.cwd(), args[catalogIndex + 1]);

  const planIndex = args.indexOf("--plan");
  const planPath =
    planIndex !== -1 && args[planIndex + 1]
      ? path.resolve(process.cwd(), args[planIndex + 1])
      : path.resolve(__dirname, "bootstrap_plan.json");

  const snapIndex = args.indexOf("--snapshot");
  const snapshotPath =
    snapIndex !== -1 && args[snapIndex + 1]
      ? path.resolve(process.cwd(), args[snapIndex + 1])
      : null;

  let existingPlanPath = fs.existsSync(planPath) ? planPath : null;

  const { plan, planStr, code, error, catalogSha256, schemaSha256 } =
    generateBootstrapPlan(catalogPath, existingPlanPath, snapshotPath);

  if (error) {
    console.error(`ERROR: ${error}`);
    process.exit(code);
  }

  console.log("--- BOOTSTRAP PLAN REPORT ---");
  console.log(`Version: ${plan.version}`);
  console.log(`Namespace UUIDv5: ${plan.namespace}`);
  console.log(`Schema Migration: ${plan.schemaMigration}`);
  console.log(`Schema SHA-256: ${plan.schemaSha256}`);
  console.log(`Catalog SHA-256: ${plan.catalogSha256}`);
  console.log(`Plan SHA-256: ${plan.planSha256}`);

  console.log("\nEntities to Upsert:");
  console.log(`  languages: ${plan.counts.languages}`);
  console.log(`  titles: ${plan.counts.titles}`);
  console.log(`  seasons: ${plan.counts.seasons}`);
  console.log(`  episodes: ${plan.counts.episodes}`);
  console.log(`  sources: ${plan.counts.sources}`);

  console.log("\nURLs Validated:");
  console.log(`  urlsInspected: ${plan.stats.urlsInspected}`);
  console.log(`  urlsValid: ${plan.stats.urlsValid}`);
  console.log(`  urlsInvalid: ${plan.stats.urlsInvalid}`);

  console.log("\nStates:");
  console.log(`  planUnchanged: ${plan.planUnchanged}`);
  console.log(`  ready: ${plan.stats.ready}`);
  console.log(`  alreadyPresent: ${plan.stats.alreadyPresent}`);
  console.log(`  invalid: ${plan.stats.invalid}`);
  console.log(`  duplicate: ${plan.stats.duplicate}`);
  console.log(`  missingParent: ${plan.stats.missingParent}`);
  console.log(`  conflict: ${plan.stats.conflict}`);

  console.log("\nExpected Audit Changes (triggers):");
  console.log(`  titles: ${plan.expectedAuditChanges.titles}`);
  console.log(`  seasons: ${plan.expectedAuditChanges.seasons}`);
  console.log(`  episodes: ${plan.expectedAuditChanges.episodes}`);
  console.log(`  sources: ${plan.expectedAuditChanges.sources}`);
  console.log(
    `  TOTAL: ${plan.expectedAuditChanges.titles + plan.expectedAuditChanges.seasons + plan.expectedAuditChanges.episodes + plan.expectedAuditChanges.sources}`,
  );

  if (code === 3) {
    console.error(
      "\nERROR: Plan contains invalid states or conflicts. Bootstrap aborted.",
    );
    process.exit(3);
  }

  if (isDryRun) {
    console.log("\nAction: Dry-run completed immutably. No files written.");
    process.exit(2);
  }

  if (isWritePlan) {
    writeAtomic(planPath, planStr);
    console.log(
      "\nAction: Plan saved atomically to " + path.basename(planPath) + ".",
    );
    process.exit(2);
  }

  process.exit(0);
}
