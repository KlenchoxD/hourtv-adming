const test = require('node:test');
const assert = require('node:assert/strict');
const { persistHealthResults, buildHealthUpdate } = require('./source-health-sync');

test('builds a bounded health update and preserves inconclusive counters', () => {
  const update = buildHealthUpdate(
    { status: 'down', consecutiveFailures: 3 },
    { ok: false, conclusive: false, reason: 'access-control', httpCode: 403 },
    '2026-09-20T12:00:00.000Z',
    'run-2',
  );
  assert.equal(update.healthStatus, 'down');
  assert.equal(update.healthConsecutiveFailures, 3);
  assert.equal(update.healthHttpCode, 403);
});

test('persists useful diagnostic detail for inconclusive probes', () => {
  const update = buildHealthUpdate(
    { status: 'active', consecutiveFailures: 0 },
    { ok: false, conclusive: false, reason: 'blocked-or-unknown', detail: 'timeout' },
    '2026-09-20T12:00:00.000Z',
    'run-2',
  );
  assert.equal(update.healthLastError, 'blocked-or-unknown: timeout');
});

test('buildHealthUpdate does not count the same health run twice', () => {
  const update = buildHealthUpdate(
    {
      status: 'suspected_down',
      consecutiveFailures: 1,
      firstFailureAt: '2026-09-20T00:00:00.000Z',
      lastCheckRunId: 'run-1',
    },
    { ok: false, conclusive: true, reason: 'http-404', httpCode: 404 },
    '2026-09-20T12:00:00.000Z',
    'run-1',
  );
  assert.equal(update.healthStatus, 'suspected_down');
  assert.equal(update.healthConsecutiveFailures, 1);
  assert.equal(update.healthLastCheckRunId, 'run-1');
});

test('persists source update and audit row in one transaction', async () => {
  const calls = [];
  const client = {
    async query(text, values) { calls.push({ text, values }); return { rows: [] }; },
  };
  await persistHealthResults(client, 'run-1', [{
    id: 'source-1',
    previous: { status: 'active', consecutiveFailures: 0 },
    result: { ok: false, conclusive: false, reason: 'blocked-or-unknown', detail: 'timeout' },
    checkedAt: '2026-09-20T12:00:00.000Z',
  }]);
  assert.equal(calls[0].text, 'BEGIN');
  assert.match(calls[1].text, /UPDATE public\.sources/);
  assert.match(calls[1].text, /\$1/);
  assert.match(calls[2].text, /INSERT INTO private\.source_health_checks/);
  assert.match(calls[3].text, /DELETE FROM private\.source_health_checks/);
  assert.match(calls[3].text, /interval '30 days'/);
  assert.equal(calls.at(-1).text, 'COMMIT');
  assert.ok(!calls.some((call) => call.text.includes('source-1')));
});

test('run preserves the previous successful-check timestamp', async () => {
  const client = { async query(text) {
    if (text.startsWith('SELECT')) return { rows: [{
      id: 'source-1',
      url: 'https://example.test/video.mp4',
      requires_webview: false,
      health_status: 'active',
      health_consecutive_failures: 0,
      health_last_success_at: '2026-09-19T08:00:00.000Z',
    }] };
    return { rows: [] };
  } };
  const report = await require('./source-health-sync').run({
    client,
    probe: async () => ({ ok: false, conclusive: false, reason: 'blocked-or-unknown', detail: 'timeout' }),
  });
  assert.equal(report.results[0].previous.lastSuccessAt, '2026-09-19T08:00:00.000Z');
  const update = buildHealthUpdate(report.results[0].previous, report.results[0].result, report.results[0].checkedAt, report.runId);
  assert.equal(update.healthLastSuccessAt, '2026-09-19T08:00:00.000Z');
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

test('refreshes a failed source from its origin page and persists the new URL', async () => {
  const client = { async query(text) {
    if (text.startsWith('SELECT')) return { rows: [{
      id: 'source-origin-1', url: 'https://voe.sx/e/old', referer_url: 'https://catalog.test/movie/pride',
      requires_webview: false, health_status: 'down', health_consecutive_failures: 3,
    }] };
    return { rows: [] };
  } };
  const report = await require('./source-health-sync').run({
    client,
    probe: async (url) => ({ ok: url.endsWith('/new'), conclusive: true, reason: 'media' }),
    refresh: async () => ({ recovered: true, originUrl: 'https://catalog.test/movie/pride', url: 'https://voe.sx/e/new', result: { ok: true, conclusive: true, reason: 'media' } }),
  });
  assert.equal(report.results[0].result.sourceUrl, 'https://voe.sx/e/new');
  const update = buildHealthUpdate(report.results[0].previous, report.results[0].result, report.results[0].checkedAt, report.runId);
  assert.equal(update.healthStatus, 'recovered');
  assert.equal(update.sourceUrl, 'https://voe.sx/e/new');
});
