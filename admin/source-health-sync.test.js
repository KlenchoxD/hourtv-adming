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

test('checks sources in bounded concurrent batches', async () => {
  let active = 0;
  let peak = 0;
  const client = { async query(text) {
    if (text.startsWith('SELECT')) return { rows: Array.from({ length: 9 }, (_, i) => ({
      id: `source-${i}`, url: `https://example.test/${i}`, health_status: 'pending', health_consecutive_failures: 0,
    })) };
    return { rows: [] };
  } };
  const report = await require('./source-health-sync').run({
    client, concurrency: 3, probe: async () => {
      active += 1; peak = Math.max(peak, active);
      await new Promise((resolve) => setTimeout(resolve, 2));
      active -= 1;
      return { ok: true, conclusive: true, reason: 'media' };
    },
  });
  assert.equal(report.total, 9);
  assert.equal(peak, 3);
});

test('does not mark HTML embeds as down when the source requires WebView', async () => {
  const client = { async query(text) {
    if (text.startsWith('SELECT')) return { rows: [{ id: 'embed-1', url: 'https://embed.test/1', requires_webview: true, health_status: 'pending', health_consecutive_failures: 0 }] };
    return { rows: [] };
  } };
  const report = await require('./source-health-sync').run({
    client, probe: async () => ({ ok: false, conclusive: true, reason: 'html' }),
  });
  assert.equal(report.results[0].result.reason, 'requires-webview');
  assert.equal(report.results[0].result.conclusive, false);
});

test('recognizes known embed hosts even when editorial flag is false', async () => {
  const client = { async query(text) {
    if (text.startsWith('SELECT')) return { rows: [{ id: 'voe-1', url: 'https://voe.sx/e/abc', requires_webview: false, health_status: 'pending', health_consecutive_failures: 0 }] };
    return { rows: [] };
  } };
  const report = await require('./source-health-sync').run({ client, probe: async () => ({ ok: false, conclusive: true, reason: 'html' }) });
  assert.equal(report.results[0].result.reason, 'requires-webview');
  assert.equal(report.results[0].result.conclusive, false);
});
