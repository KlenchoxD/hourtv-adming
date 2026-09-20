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

test('does not count access-control responses as server downtime', () => {
  const result = classifyProbe({ status: 403, contentType: 'text/html', body: Buffer.from('forbidden') });
  assert.deepEqual(result, { ok: false, conclusive: false, reason: 'access-control', httpCode: 403 });
});

test('transitions failures and recovery deterministically', () => {
  const initial = { status: 'active', consecutiveFailures: 0 };
  const first = nextHealth(initial, { ok: false, conclusive: true, reason: 'timeout' });
  const second = nextHealth(first, { ok: false, conclusive: true, reason: 'timeout' });
  const third = nextHealth(second, { ok: false, conclusive: true, reason: 'timeout' });
  assert.equal(first.status, 'degraded');
  assert.equal(second.status, 'degraded');
  assert.equal(third.status, 'down');
  assert.equal(nextHealth(third, { ok: true, conclusive: true, reason: 'media' }).status, 'recovered');
});

test('inconclusive failures preserve health counters', () => {
  const result = nextHealth({ status: 'down', consecutiveFailures: 3 }, { ok: false, conclusive: false, reason: 'access-control' });
  assert.equal(result.status, 'down');
  assert.equal(result.consecutiveFailures, 3);
  assert.equal(result.conclusive, false);
});

test('probeUrl uses bounded GET ranges and validates the HLS segment', async () => {
  const calls = [];
  const response = (status, type, body) => ({
    status,
    headers: new Headers({ 'content-type': type }),
    body: new Response(body).body,
  });
  const result = await probeUrl('https://cdn.example.test/master.m3u8', {
    fetchImpl: async (url, init) => {
      calls.push({ url: String(url), init });
      return calls.length === 1
        ? response(200, 'application/vnd.apple.mpegurl', '#EXTM3U\n#EXTINF:4,\npart.ts')
        : response(206, 'video/mp2t', Buffer.from([0x47, 0x00, 0x00]));
    },
  });
  assert.equal(result.ok, true);
  assert.equal(calls.length, 2);
  assert.equal(calls[0].init.headers.Range, 'bytes=0-2048');
  assert.equal(calls[1].url, 'https://cdn.example.test/part.ts');
});
