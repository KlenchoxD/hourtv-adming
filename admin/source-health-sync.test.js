const test = require('node:test');
const assert = require('node:assert/strict');
const { persistHealthResults, buildHealthUpdate } = require('./source-health-sync');

test('builds a bounded health update and preserves inconclusive counters', () => {
  const update = buildHealthUpdate(
    { status: 'down', consecutiveFailures: 3 },
    { ok: false, conclusive: false, reason: 'access-control', httpCode: 403 },
    '2026-09-20T12:00:00.000Z',
  );
  assert.equal(update.healthStatus, 'down');
  assert.equal(update.healthConsecutiveFailures, 3);
  assert.equal(update.healthHttpCode, 403);
});

test('persists source update and audit row in one transaction', async () => {
  const calls = [];
  const client = {
    async query(text, values) { calls.push({ text, values }); return { rows: [] }; },
  };
  await persistHealthResults(client, 'run-1', [{
    id: 'source-1',
    previous: { status: 'active', consecutiveFailures: 0 },
    result: { ok: false, conclusive: true, reason: 'timeout' },
    checkedAt: '2026-09-20T12:00:00.000Z',
  }]);
  assert.equal(calls[0].text, 'BEGIN');
  assert.match(calls[1].text, /UPDATE public\.sources/);
  assert.match(calls[1].text, /\$1/);
  assert.match(calls[2].text, /INSERT INTO private\.source_health_checks/);
  assert.equal(calls.at(-1).text, 'COMMIT');
  assert.ok(!calls.some((call) => call.text.includes('source-1')));
});

test('rolls back if any source update fails', async () => {
  const calls = [];
  const client = {
    async query(text, values) {
      calls.push({ text, values });
      if (text.startsWith('UPDATE')) throw new Error('db failure');
      return { rows: [] };
    },
  };
  await assert.rejects(() => persistHealthResults(client, 'run-1', [{
    id: 'source-1', previous: {}, result: { ok: true, conclusive: true }, checkedAt: '2026-09-20T12:00:00.000Z',
  }]));
  assert.equal(calls.at(-1).text, 'ROLLBACK');
});
