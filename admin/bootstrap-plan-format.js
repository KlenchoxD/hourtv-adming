const crypto = require("crypto");

const PLAN_VERSION = 3;

function computeLogicalHash(plan) {
  const logicalPlan = {
    version: plan.version,
    namespace: plan.namespace,
    schemaMigration: plan.schemaMigration,
    schemaSha256: plan.schemaSha256,
    catalogSha256: plan.catalogSha256,
    operations: plan.operations,
  };
  return crypto
    .createHash("sha256")
    .update(JSON.stringify(logicalPlan))
    .digest("hex");
}

module.exports = {
  PLAN_VERSION,
  computeLogicalHash,
};
