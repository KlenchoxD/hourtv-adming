const test = require('node:test');
const assert = require('node:assert/strict');
const { classifyProbe, nextHealth, probeUrl } = require('./source-health-check');

test('accepts a direct media response with valid magic bytes', () => {
  const result = classifyProbe({ status: 200, contentType: 'video/mp4', body: Buffer.from('....ftypisom') });
  assert.deepEqual(result, { ok: true, conclusive: true, reason: 'media' });
});

test('accepts HLS only after a media segment is validated', () => {
  const result = classifyProbe({
    status: 200,
    contentType: 'application/vnd.apple.mpegurl',
    body: Buffer.from('#EXTM3U\n#EXTINF:4,\nsegment.ts'),
    segment: { status: 206, contentType: 'video/mp2t', body: Buffer.from([0x47, 0x40, 0x00]) },
  });
  assert.deepEqual(result, { ok: true, conclusive: true, reason: 'hls-segment' });
});

test('rejects HTML masquerading as a media response', () => {
  const result = classifyProbe({ status: 200, contentType: 'video/mp4', body: Buffer.from('<html>blocked</html>') });
  assert.equal(result.ok, false);
  assert.equal(result.conclusive, true);
  assert.equal(result.reason, 'html');
});

test('classifies access-control and transient HTTP responses as blocked or unknown', () => {
  for (const status of [401, 403, 405, 429, 503]) {
    const result = classifyProbe({ status, contentType: 'text/html', body: Buffer.from('blocked') });
    assert.deepEqual(result, { ok: false, conclusive: false, reason: 'blocked-or-unknown', httpCode: status });
  }
});

test('requires three distinct runs and twelve hours before confirming down', () => {
  const initial = { status: 'active', consecutiveFailures: 0 };
  const failure = { ok: false, conclusive: true, reason: 'http-404', httpCode: 404 };
  const first = nextHealth(initial, failure, '2026-09-20T00:00:00.000Z', 'run-1');
  const duplicate = nextHealth(first, failure, '2026-09-20T01:00:00.000Z', 'run-1');
  const second = nextHealth(duplicate, failure, '2026-09-20T06:00:00.000Z', 'run-2');
  const tooEarlyThird = nextHealth(second, failure, '2026-09-20T11:59:59.000Z', 'run-3');
  const third = nextHealth(second, failure, '2026-09-20T12:00:00.000Z', 'run-3');
  assert.equal(first.status, 'suspected_down');
  assert.equal(duplicate.consecutiveFailures, 1);
  assert.equal(second.status, 'suspected_down');
  assert.equal(tooEarlyThird.status, 'suspected_down');
  assert.equal(third.status, 'down');
  assert.equal(nextHealth(third, { ok: true, conclusive: true, reason: 'media' }, '2026-09-20T13:00:00.000Z', 'run-4').status, 'recovered');
});

test('inconclusive failures use blocked_or_unknown without changing counters', () => {
  const active = nextHealth(
    { status: 'active', consecutiveFailures: 1, firstFailureAt: '2026-09-19T00:00:00.000Z' },
    { ok: false, conclusive: false, reason: 'blocked-or-unknown', httpCode: 403 },
    '2026-09-20T12:00:00.000Z',
    'run-2',
  );
  const down = nextHealth(
    { status: 'down', consecutiveFailures: 3 },
    { ok: false, conclusive: false, reason: 'blocked-or-unknown' },
    '2026-09-20T12:00:00.000Z',
    'run-2',
  );
  assert.equal(active.status, 'blocked_or_unknown');
  assert.equal(active.consecutiveFailures, 1);
  assert.equal(active.firstFailureAt, '2026-09-19T00:00:00.000Z');
  assert.equal(down.status, 'down');
  assert.equal(down.consecutiveFailures, 3);
});

test('probeUrl follows redirects, tries HEAD before bounded GET, and validates the HLS segment', async () => {
  const calls = [];
  const response = (status, type, body) => ({
    status,
    headers: new Headers({ 'content-type': type }),
    body: new Response(body).body,
  });
  const result = await probeUrl('https://cdn.example.test/master.m3u8', {
    fetchImpl: async (url, init) => {
      calls.push({ url: String(url), init });
      if (calls.length === 1) return response(200, 'application/vnd.apple.mpegurl', '');
      return calls.length === 2
        ? response(200, 'application/vnd.apple.mpegurl', '#EXTM3U\n#EXTINF:4,\npart.ts')
        : response(206, 'video/mp2t', Buffer.from([0x47, 0x00, 0x00]));
    },
  });
  assert.equal(result.ok, true);
  assert.equal(calls.length, 3);
  assert.equal(calls[0].init.method, 'HEAD');
  assert.equal(calls[0].init.redirect, 'follow');
  assert.equal(calls[1].init.method, 'GET');
  assert.equal(calls[1].init.headers.Range, 'bytes=0-2048');
  assert.equal(calls[2].url, 'https://cdn.example.test/part.ts');
});

test('probeUrl falls back to GET when HEAD is not supported', async () => {
  const calls = [];
  const response = (status, type, body) => ({
    status,
    headers: new Headers({ 'content-type': type }),
    body: new Response(body).body,
  });
  const result = await probeUrl('https://cdn.example.test/movie.mp4', {
    fetchImpl: async (_url, init) => {
      calls.push(init);
      return calls.length === 1
        ? response(405, 'text/plain', '')
        : response(206, 'video/mp4', Buffer.from('....ftypisom'));
    },
  });
  assert.equal(result.ok, true);
  assert.deepEqual(calls.map((call) => call.method), ['HEAD', 'GET']);
});

test('probeUrl treats timeouts and DNS errors as inconclusive', async () => {
  for (const error of [Object.assign(new Error('timed out'), { name: 'AbortError' }), Object.assign(new Error('not found'), { code: 'ENOTFOUND' })]) {
    const result = await probeUrl('https://unavailable.example.test/video.mp4', {
      fetchImpl: async () => { throw error; },
    });
    assert.equal(result.ok, false);
    assert.equal(result.conclusive, false);
    assert.equal(result.reason, 'blocked-or-unknown');
  }
});
