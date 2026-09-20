const { test } = require("node:test");
const assert = require("node:assert");
const cp = require("child_process");
const path = require("path");
const fs = require("fs");
const crypto = require("crypto");
const os = require("os");
const {
  generateBootstrapPlan,
  writeAtomic,
  uuidv5,
  NAMESPACE,
  SCHEMA_SIGNATURE,
  isValidUrl,
} = require("./bootstrap-catalog");

const validUUID = "550e8400-e29b-41d4-a716-446655440000";

function withTempFiles(cb) {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "hourtv-test-bs-"));
  const catPath = path.join(tmpDir, "catalog.json");
  const planPath = path.join(tmpDir, "plan.json");
  const snapPath = path.join(tmpDir, "snap.json");
  try {
    cb(tmpDir, catPath, planPath, snapPath);
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
}

test("URL validator works according to chk_sources_url_secure", () => {
  assert.strictEqual(isValidUrl("https://example.com"), true);
  assert.strictEqual(isValidUrl("http://example.com"), false);
  assert.strictEqual(isValidUrl("https://user:pass@example.com"), false);
  assert.strictEqual(isValidUrl("https://localhost:3000"), false);
  assert.strictEqual(isValidUrl("https://127.0.0.1"), false);
  assert.strictEqual(isValidUrl("https://10.0.0.1"), false);
  assert.strictEqual(isValidUrl("https://192.168.1.1"), false);
  assert.strictEqual(isValidUrl("https://example.com?token=123"), false);
  assert.strictEqual(isValidUrl("https://example.com/api_key=123"), true);
});

test("UUIDv5 determinism and namespace stability", () => {
  const v1 = uuidv5("lang:es", NAMESPACE);
  const v2 = uuidv5("lang:es", NAMESPACE);
  assert.strictEqual(v1, v2);
  assert.strictEqual(v1, "d54c860b-187c-5bcf-998b-5f63dd656d38");
});

test("Idioma desconocido is invalid", () => {
  withTempFiles((tmpDir, catPath) => {
    fs.writeFileSync(
      catPath,
      JSON.stringify({
        movies: [
          {
            id: "m1",
            title: "M1",
            servers: [
              {
                id: validUUID,
                language: "Frances",
                name: "S1",
                url: "https://a.com",
              },
            ],
          },
        ],
      }),
    );
    const { plan, code } = generateBootstrapPlan(catPath);
    assert.strictEqual(code, 3);
    assert.strictEqual(plan.stats.invalid, 1);
  });
});

test("URL inválida aborts", () => {
  withTempFiles((tmpDir, catPath) => {
    fs.writeFileSync(
      catPath,
      JSON.stringify({
        movies: [
          {
            id: "m1",
            title: "M1",
            servers: [
              {
                id: validUUID,
                language: "Español",
                name: "S1",
                url: "http://insecure.com",
              },
            ],
          },
        ],
      }),
    );
    const { plan, code } = generateBootstrapPlan(catPath);
    assert.strictEqual(code, 3);
    assert.strictEqual(plan.stats.invalid, 1);
    assert.strictEqual(plan.stats.urlsInvalid, 1);
  });
});

test("Special characters are preserved exactly as data without interpolation", () => {
  withTempFiles((tmpDir, catPath) => {
    fs.writeFileSync(
      catPath,
      JSON.stringify({
        movies: [
          { id: "m1", title: "Robert'); DROP TABLE titles;--", servers: [] },
        ],
      }),
    );
    const { plan, code } = generateBootstrapPlan(catPath);
    assert.strictEqual(code, 2);
    assert.strictEqual(
      plan.operations[0].record.title,
      "Robert'); DROP TABLE titles;--",
    );
  });
});

test("Incompatible schema version aborts", () => {
  withTempFiles((tmpDir, catPath, planPath) => {
    fs.writeFileSync(catPath, JSON.stringify({ movies: [] }));
    const { plan } = generateBootstrapPlan(catPath);
    plan.schemaMigration = "old_schema.sql";
    fs.writeFileSync(planPath, JSON.stringify(plan));

    const res = generateBootstrapPlan(catPath, planPath);
    assert.strictEqual(res.code, 3);
    assert.match(res.error, /Incompatible schema version/);
  });
});

test("Schema file content changed aborts", () => {
  withTempFiles((tmpDir, catPath, planPath) => {
    fs.writeFileSync(catPath, JSON.stringify({ movies: [] }));
    const { plan } = generateBootstrapPlan(catPath);
    plan.schemaSha256 = "fakehash123";

    // Recalculate planSha256 so it doesn't fail on "corrupt content" first
    const planStrWithoutHash = JSON.stringify(plan);
    plan.planSha256 = require("crypto")
      .createHash("sha256")
      .update(planStrWithoutHash)
      .digest("hex");

    fs.writeFileSync(planPath, JSON.stringify(plan));

    const res = generateBootstrapPlan(catPath, planPath);
    assert.strictEqual(res.code, 3);
    assert.match(
      res.error,
      /Schema file content changed after plan generation/,
    );
  });
});

// NEW 1: missingParent
test("Missing parent for season, episode and source", () => {
  withTempFiles((tmpDir, catPath) => {
    fs.writeFileSync(
      catPath,
      JSON.stringify({
        series: [
          {
            title: null,
            id: null,
            tmdbId: null,
            seasons: [{ number: 1, episodes: [] }],
          },
        ],
      }),
    );
    const { plan, code } = generateBootstrapPlan(catPath);
    assert.strictEqual(code, 3);
    assert.strictEqual(plan.stats.invalid, 1);
    assert.strictEqual(plan.stats.missingParent, 1);
  });
});

// NEW 2: Identidad canónica duplicada
test("Identidad canónica duplicada", () => {
  withTempFiles((tmpDir, catPath) => {
    fs.writeFileSync(
      catPath,
      JSON.stringify({
        movies: [
          { id: "m1", title: "M1", servers: [] },
          { id: "m1", title: "M1 dup", servers: [] },
        ],
      }),
    );
    const { plan, code } = generateBootstrapPlan(catPath);
    assert.strictEqual(code, 3);
    assert.strictEqual(plan.stats.duplicate, 1);
  });
});

test("TMDB duplicado dentro del mismo tipo de contenido aborta el plan", () => {
  withTempFiles((tmpDir, catPath) => {
    fs.writeFileSync(
      catPath,
      JSON.stringify({
        movies: [
          { id: "legacy-2017", tmdbId: 335777, title: "Película", servers: [] },
          {
            id: "legacy-2014",
            tmdbId: 335777,
            title: "Película duplicada",
            servers: [],
          },
        ],
      }),
    );

    const { plan, code } = generateBootstrapPlan(catPath);

    assert.strictEqual(code, 3);
    assert.strictEqual(plan.stats.duplicate, 1);
    assert.strictEqual(
      plan.operations.filter((op) => op.entityType === "title").length,
      1,
    );
  });
});

// NEW 3: UUID duplicado
test("UUID duplicado entre entidades u operaciones", () => {
  withTempFiles((tmpDir, catPath) => {
    fs.writeFileSync(
      catPath,
      JSON.stringify({
        movies: [
          {
            id: "m1",
            title: "M1",
            servers: [
              { id: validUUID, language: "Español", url: "https://a.com" },
              { id: validUUID, language: "Inglés", url: "https://b.com" },
            ],
          },
        ],
      }),
    );
    const { plan, code } = generateBootstrapPlan(catPath);
    assert.strictEqual(code, 3);
    assert.strictEqual(plan.stats.duplicate, 1); // The second source with validUUID
  });
});

// NEW 4: Catálogo modificado
test("Catálogo modificado después de escribir el plan: rechazo por catalogSha256", () => {
  withTempFiles((tmpDir, catPath, planPath) => {
    fs.writeFileSync(
      catPath,
      JSON.stringify({ movies: [{ id: "m1", title: "M1", servers: [] }] }),
    );
    const { planStr } = generateBootstrapPlan(catPath);
    fs.writeFileSync(planPath, planStr);

    fs.writeFileSync(
      catPath,
      JSON.stringify({
        movies: [{ id: "m1", title: "M1 modificado", servers: [] }],
      }),
    );
    const res = generateBootstrapPlan(catPath, planPath);
    assert.strictEqual(res.code, 3);
    assert.match(res.error, /Catalog changed after plan generation/);
  });
});

// NEW 5: Plan manipulado o corrupto
test("Plan con planSha256 manipulado o contenido corrupto", () => {
  withTempFiles((tmpDir, catPath, planPath) => {
    fs.writeFileSync(
      catPath,
      JSON.stringify({ movies: [{ id: "m1", title: "M1", servers: [] }] }),
    );
    const { planStr } = generateBootstrapPlan(catPath);

    const plan = JSON.parse(planStr);
    plan.namespace = "00000000-0000-0000-0000-000000000000"; // corrupt!
    fs.writeFileSync(planPath, JSON.stringify(plan));

    const res = generateBootstrapPlan(catPath, planPath);
    assert.strictEqual(res.code, 3);
    assert.match(res.error, /Plan corrupted or manipulated/);
  });
});

// NEW 6: Dos ejecuciones producen mismos bytes y SHA-256
test("Dos ejecuciones consecutivas de --write-plan producen exactamente los mismos bytes y SHA-256", () => {
  withTempFiles((tmpDir, catPath, planPath1) => {
    fs.writeFileSync(
      catPath,
      JSON.stringify({ movies: [{ id: "m1", title: "M1", servers: [] }] }),
    );
    const planPath2 = path.join(tmpDir, "plan2.json");
    const scriptPath = path.resolve(__dirname, "bootstrap-catalog.js");

    cp.spawnSync(
      "node",
      [scriptPath, "--write-plan", "--catalog", catPath, "--plan", planPath1],
      { cwd: __dirname },
    );
    cp.spawnSync(
      "node",
      [scriptPath, "--write-plan", "--catalog", catPath, "--plan", planPath2],
      { cwd: __dirname },
    );

    const buf1 = fs.readFileSync(planPath1);
    const buf2 = fs.readFileSync(planPath2);
    assert.deepStrictEqual(buf1, buf2);
  });
});

// NEW 7: Plan idéntico previo genera planUnchanged
test("Plan idéntico previo genera planUnchanged", () => {
  withTempFiles((tmpDir, catPath, planPath) => {
    fs.writeFileSync(
      catPath,
      JSON.stringify({ movies: [{ id: "m1", title: "M1", servers: [] }] }),
    );
    const { planStr } = generateBootstrapPlan(catPath);
    fs.writeFileSync(planPath, planStr);

    const { plan, code } = generateBootstrapPlan(catPath, planPath);
    assert.strictEqual(code, 2);
    assert.strictEqual(plan.planUnchanged, true);
    assert.strictEqual(plan.stats.alreadyPresent, 0); // Not a DB snapshot
  });
});

// NEW 8: Snapshot autoritativo con fila idéntica -> alreadyPresent
test("Snapshot autoritativo simulado con fila idéntica produce alreadyPresent", () => {
  withTempFiles((tmpDir, catPath, planPath, snapPath) => {
    fs.writeFileSync(
      catPath,
      JSON.stringify({ movies: [{ id: "m1", title: "M1", servers: [] }] }),
    );

    const { plan: firstPlan } = generateBootstrapPlan(catPath);
    const titleRec = firstPlan.operations[0].record; // the only record is the title

    fs.writeFileSync(
      snapPath,
      JSON.stringify({
        authoritative: true,
        records: [{ id: titleRec.id, type: "title", data: titleRec }],
      }),
    );

    const { plan, code } = generateBootstrapPlan(catPath, null, snapPath);
    assert.strictEqual(code, 2);
    assert.strictEqual(plan.stats.alreadyPresent, 1);
    assert.strictEqual(plan.stats.ready, 0);
  });
});

// NEW 9: Snapshot autoritativo con mismo UUID e info distinta -> conflict
test("Snapshot autoritativo simulado con el mismo UUID e información distinta produce conflict", () => {
  withTempFiles((tmpDir, catPath, planPath, snapPath) => {
    fs.writeFileSync(
      catPath,
      JSON.stringify({ movies: [{ id: "m1", title: "M1", servers: [] }] }),
    );

    const { plan: firstPlan } = generateBootstrapPlan(catPath);
    const titleRec = JSON.parse(JSON.stringify(firstPlan.operations[0].record));
    titleRec.title = "M1 DB Changed"; // different info

    fs.writeFileSync(
      snapPath,
      JSON.stringify({
        authoritative: true,
        records: [{ id: titleRec.id, type: "title", data: titleRec }],
      }),
    );

    const { plan, code } = generateBootstrapPlan(catPath, null, snapPath);
    assert.strictEqual(code, 3);
    assert.strictEqual(plan.stats.conflict, 1);
  });
});

// NEW 10: Snapshot RLS-limited -> never alreadyPresent
test("Snapshot RLS-limited o sin autoridad nunca permite calcular alreadyPresent", () => {
  withTempFiles((tmpDir, catPath, planPath, snapPath) => {
    fs.writeFileSync(
      catPath,
      JSON.stringify({ movies: [{ id: "m1", title: "M1", servers: [] }] }),
    );

    const { plan: firstPlan } = generateBootstrapPlan(catPath);
    const titleRec = firstPlan.operations[0].record;

    fs.writeFileSync(
      snapPath,
      JSON.stringify({
        authoritative: false, // NOT authoritative
        records: [{ id: titleRec.id, type: "title", data: titleRec }],
      }),
    );

    const { plan, code } = generateBootstrapPlan(catPath, null, snapPath);
    assert.strictEqual(code, 2);
    assert.strictEqual(plan.stats.alreadyPresent, 0); // Ignore snapshot
    assert.strictEqual(plan.stats.ready, 1);
  });
});

// NEW 11: Igualdad dry-run/write-plan/read-back
test("Igualdad dry-run/write-plan/read-back", () => {
  withTempFiles((tmpDir, catPath, planPath) => {
    fs.writeFileSync(
      catPath,
      JSON.stringify({ movies: [{ id: "m1", title: "M1", servers: [] }] }),
    );
    const { plan: dryRunPlan } = generateBootstrapPlan(catPath);

    const { plan: writePlanGen } = generateBootstrapPlan(catPath, null);
    fs.writeFileSync(planPath, JSON.stringify(writePlanGen));

    const { plan: readBackPlan } = generateBootstrapPlan(catPath, planPath);

    assert.strictEqual(dryRunPlan.planSha256, writePlanGen.planSha256);
    assert.strictEqual(writePlanGen.planSha256, readBackPlan.planSha256);
  });
});

// NEW 12: Independencia de la ruta de salida
test("Independencia de la ruta de salida", () => {
  withTempFiles((tmpDir, catPath) => {
    fs.writeFileSync(
      catPath,
      JSON.stringify({ movies: [{ id: "m1", title: "M1", servers: [] }] }),
    );
    const { plan: p1 } = generateBootstrapPlan(catPath, "/fake/path/1.json");
    const { plan: p2 } = generateBootstrapPlan(catPath, "/another/path/2.json");
    assert.strictEqual(p1.planSha256, p2.planSha256);
  });
});

// NEW 13: Independencia de timestamps y estado planUnchanged
test("Independencia de timestamps y estado planUnchanged", () => {
  withTempFiles((tmpDir, catPath, planPath) => {
    fs.writeFileSync(
      catPath,
      JSON.stringify({ movies: [{ id: "m1", title: "M1", servers: [] }] }),
    );
    const { plan } = generateBootstrapPlan(catPath);
    const hashUnchangedFalse = plan.planSha256;

    plan.planUnchanged = true;
    fs.writeFileSync(planPath, JSON.stringify(plan));
    const res = generateBootstrapPlan(catPath, planPath);

    assert.strictEqual(res.plan.planSha256, hashUnchangedFalse);
  });
});

// NEW 14: Verificación fallida si cambia una operación real
test("Verificación fallida si cambia una operación real", () => {
  withTempFiles((tmpDir, catPath, planPath) => {
    fs.writeFileSync(
      catPath,
      JSON.stringify({ movies: [{ id: "m1", title: "M1", servers: [] }] }),
    );
    const { plan } = generateBootstrapPlan(catPath);

    plan.operations[0].record.title = "HACKED";
    fs.writeFileSync(planPath, JSON.stringify(plan));

    const res = generateBootstrapPlan(catPath, planPath);
    assert.strictEqual(res.code, 3);
    assert.match(res.error, /Plan corrupted or manipulated/);
  });
});

// NEW 15: Help flag works and exits with 0
test("Help flag works without other arguments", () => {
  const scriptPath = path.resolve(__dirname, "bootstrap-catalog.js");
  const res = cp.spawnSync("node", [scriptPath, "--help"], {
    encoding: "utf8",
  });
  assert.strictEqual(res.status, 0);
  assert.match(res.stdout, /Usage: node bootstrap-catalog.js/);
});

test("--write-plan accepts its documented output path directly", () => {
  withTempFiles((tmpDir, catPath, planPath) => {
    fs.writeFileSync(catPath, JSON.stringify({ movies: [] }));
    const scriptPath = path.resolve(__dirname, "bootstrap-catalog.js");

    const res = cp.spawnSync(
      "node",
      [scriptPath, "--write-plan", planPath, "--catalog", catPath],
      { encoding: "utf8" },
    );

    assert.strictEqual(res.status, 2);
    assert.strictEqual(fs.existsSync(planPath), true);
    assert.match(res.stdout, new RegExp(path.basename(planPath)));
  });
});

test("rewriting the same plan path preserves identical bytes", () => {
  withTempFiles((tmpDir, catPath, planPath) => {
    fs.writeFileSync(catPath, JSON.stringify({ movies: [] }));
    const scriptPath = path.resolve(__dirname, "bootstrap-catalog.js");
    const args = [scriptPath, "--write-plan", planPath, "--catalog", catPath];

    const first = cp.spawnSync("node", args, { encoding: "utf8" });
    assert.strictEqual(first.status, 2);
    const firstBytes = fs.readFileSync(planPath);

    const second = cp.spawnSync("node", args, { encoding: "utf8" });
    assert.strictEqual(second.status, 2);
    const secondBytes = fs.readFileSync(planPath);

    assert.deepStrictEqual(secondBytes, firstBytes);
    assert.match(second.stdout, /planUnchanged: true/);
  });
});
