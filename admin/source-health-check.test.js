const test = require('node:test');
const assert = require('node:assert/strict');
const { classifyProbe, nextHealth, probeUrl } = require('./source-health-check');

test('accepts a direct media response with valid magic bytes', () => {
  const result = classifyProbe({ status: 200, contentType: 'video/mp4', body: Buffer.from('....ftypisom') });
  assert.deepEqual(result, { ok: true, conclusive: true, reason: 'media' });
});

test('accepts HLS only after a media segment is validated', () => {
  const transportStream = Buffer.alloc(377);
  transportStream[0] = 0x47;
  transportStream[188] = 0x47;
  const result = classifyProbe({
    status: 200,
    contentType: 'application/vnd.apple.mpegurl',
    body: Buffer.from('#EXTM3U\n#EXTINF:4,\nsegment.ts'),
    segment: { status: 206, contentType: 'video/mp2t', body: transportStream },
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

test('probes media declared inside an embed page instead of treating HTML 200 as healthy', async () => {
  const calls = [];
  const html = '<html><script>sources: [{"file":"https://media.example.test/pride/video.m3u8"}]</script></html>';
  const result = await probeUrl('https://barmonrey.example.test/player/pride', {
    fetchImpl: async (url, init) => {
      calls.push(String(url));
      if (init.method === 'HEAD') return { status: 200, url: String(url), headers: new Headers({ 'content-type': 'text/html' }), body: null };
      if (String(url).includes('video.m3u8')) return { status: 404, url: String(url), headers: new Headers({ 'content-type': 'text/plain' }), body: new Response('missing').body };
      return { status: 200, url: String(url), headers: new Headers({ 'content-type': 'text/html' }), body: new Response(html).body };
    },
  });
  assert.equal(result.conclusive, true);
  assert.equal(result.reason, 'http-404');
  assert.ok(calls.some(url => url.includes('video.m3u8')));
});

test('rejects arbitrary octet-stream payloads', () => {
  for (const body of [Buffer.from('{"advertisement":true}'), Buffer.from('plain text payload')]) {
    const result = classifyProbe({ status: 200, contentType: 'application/octet-stream', body });
    assert.equal(result.ok, false);
    assert.equal(result.reason, 'invalid-media');
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
  const recovered = nextHealth(third, { ok: true, conclusive: true, reason: 'media' }, '2026-09-20T13:00:00.000Z', 'run-4');
  assert.equal(recovered.status, 'recovered');
  assert.equal(recovered.firstFailureAt, null);
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

test('probeUrl resolves a master playlist against final response URLs and forwards request context', async () => {
  const calls = [];
  const response = (status, type, body, url, extraHeaders = {}) => ({
    status,
    url,
    headers: new Headers({ 'content-type': type, ...extraHeaders }),
    body: new Response(body).body,
  });
  const transportStream = Buffer.alloc(377);
  transportStream[0] = 0x47;
  transportStream[188] = 0x47;
  const result = await probeUrl('https://origin.example.test/start', {
    fetchImpl: async (url, init) => {
      const target = String(url);
      calls.push({ url: target, init });
      if (target === 'https://origin.example.test/start') {
        return response(302, 'text/plain', '', target, { location: 'https://edge.example.test/live/master.m3u8' });
      }
      if (target === 'https://edge.example.test/live/master.m3u8' && init.method === 'HEAD') {
        return response(200, 'application/vnd.apple.mpegurl', '', target);
      }
      if (target === 'https://edge.example.test/live/master.m3u8') {
        return response(
          200,
          'application/vnd.apple.mpegurl',
          '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1200000\nvariants/720p.m3u8',
          'https://edge.example.test/live/master.m3u8',
          { 'set-cookie': 'stream_session=abc123; Path=/; HttpOnly' },
        );
      }
      if (target === 'https://edge.example.test/live/variants/720p.m3u8') {
        return response(
          200,
          'application/vnd.apple.mpegurl',
          '#EXTM3U\n#EXTINF:4,\n../segments/part-1.ts',
          'https://edge.example.test/live/variants/720p.m3u8',
        );
      }
      return response(206, 'application/octet-stream', transportStream, 'https://edge.example.test/live/segments/part-1.ts');
    },
  });
  assert.equal(result.ok, true);
  assert.equal(calls.length, 6);
  assert.equal(calls[0].init.method, 'HEAD');
  assert.equal(calls[0].init.redirect, 'manual');
  assert.equal(calls[4].url, 'https://edge.example.test/live/variants/720p.m3u8');
  assert.equal(calls[5].url, 'https://edge.example.test/live/segments/part-1.ts');
  assert.equal(calls[4].init.headers.Cookie, 'stream_session=abc123');
  assert.equal(calls[5].init.headers.Referer, 'https://edge.example.test/live/variants/720p.m3u8');
  assert.equal(calls[5].init.headers.Origin, 'https://edge.example.test');
  assert.match(calls[5].init.headers['User-Agent'], /HourTV/);
});

test('probeUrl does not use an ad-marked HLS segment as playback proof', async () => {
  const requested = [];
  const transportStream = Buffer.alloc(377);
  transportStream[0] = 0x47;
  transportStream[188] = 0x47;
  const response = (status, type, body, url) => ({
    status,
    url,
    headers: new Headers({ 'content-type': type }),
    body: new Response(body).body,
  });
  const result = await probeUrl('https://cdn.example.test/live.m3u8', {
    fetchImpl: async (url, init) => {
      requested.push(String(url));
      if (init.method === 'HEAD') return response(200, 'application/vnd.apple.mpegurl', '', String(url));
      if (requested.length === 2) {
        return response(
          200,
          'application/vnd.apple.mpegurl',
          '#EXTM3U\n#EXT-X-CUE-OUT:30\nad.ts\n#EXT-X-CUE-IN\n#EXTINF:4,\ncontent.ts',
          String(url),
        );
      }
      return response(206, 'video/mp2t', transportStream, String(url));
    },
  });
  assert.equal(result.ok, true);
  assert.equal(requested.at(-1), 'https://cdn.example.test/content.ts');
});

test('probeUrl lets GET recover from a conclusive HEAD status', async () => {
  for (const headStatus of [404, 410, 500]) {
    const calls = [];
    const response = (status, type, body, url) => ({
      status,
      url,
      headers: new Headers({ 'content-type': type }),
      body: new Response(body).body,
    });
    const result = await probeUrl('https://cdn.example.test/movie.mp4', {
      fetchImpl: async (url, init) => {
        calls.push(init.method);
        return init.method === 'HEAD'
          ? response(headStatus, 'text/plain', '', String(url))
          : response(206, 'video/mp4', Buffer.from('....ftypisom'), String(url));
      },
    });
    assert.equal(result.ok, true);
    assert.deepEqual(calls, ['HEAD', 'GET']);
  }
});

test('probeUrl lets GET recover when HEAD throws or times out', async () => {
  for (const headError of [new Error('head failed'), Object.assign(new Error('head timeout'), { name: 'AbortError' })]) {
    const calls = [];
    const result = await probeUrl('https://cdn.example.test/movie.mp4', {
      fetchImpl: async (url, init) => {
        calls.push(init.method);
        if (init.method === 'HEAD') throw headError;
        return {
          status: 206,
          url: String(url),
          headers: new Headers({ 'content-type': 'video/mp4' }),
          body: new Response(Buffer.from('....ftypisom')).body,
        };
      },
    });
    assert.equal(result.ok, true);
    assert.deepEqual(calls, ['HEAD', 'GET']);
  }
});

test('probeUrl falls back to GET when HEAD is not supported', async () => {
  const calls = [];
  const response = (status, type, body) => ({
    status,
    url: 'https://cdn.example.test/movie.mp4',
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

test('probeUrl treats timeouts as inconclusive and confirmed DNS absence as down', async () => {
  for (const error of [Object.assign(new Error('timed out'), { name: 'AbortError' }), Object.assign(new Error('not found'), { code: 'ENOTFOUND' })]) {
    const result = await probeUrl('https://unavailable.example.test/video.mp4', {
      fetchImpl: async () => { throw error; },
    });
    assert.equal(result.ok, false);
    assert.equal(result.conclusive, error.code === 'ENOTFOUND');
    if (error.code === 'ENOTFOUND') assert.equal(result.permanent, true);
    else assert.equal(result.permanent, undefined);
    assert.equal(result.reason, error.code === 'ENOTFOUND' ? 'dns' : 'blocked-or-unknown');
    assert.match(result.detail, /^(timeout|dns)$/);
  }
});

test('permanent DNS failure confirms a source as down immediately', () => {
  const result = nextHealth(
    { status: 'active', consecutiveFailures: 0 },
    { ok: false, conclusive: true, permanent: true, reason: 'dns' },
    '2026-09-23T00:00:00.000Z',
    'run-dns',
  );
  assert.equal(result.status, 'down');
  assert.equal(result.consecutiveFailures, 1);
});

test('probeUrl times out when headers arrive but reading the body stalls', async () => {
  const result = await probeUrl('https://cdn.example.test/movie.mp4', {
    timeoutMs: 10,
    fetchImpl: async (url, init) => {
      if (init.method === 'HEAD') {
        return { status: 200, url: String(url), headers: new Headers({ 'content-type': 'video/mp4' }) };
      }
      return {
        status: 206,
        url: String(url),
        headers: new Headers({ 'content-type': 'video/mp4' }),
        body: {
          getReader() {
            return {
              read: () => new Promise((_resolve, reject) => {
                init.signal.addEventListener('abort', () => reject(Object.assign(new Error('body timeout'), { name: 'AbortError' })), { once: true });
              }),
              cancel: async () => {},
            };
          },
        },
      };
    },
  });
  assert.deepEqual(result, {
    ok: false,
    conclusive: false,
    reason: 'blocked-or-unknown',
    detail: 'timeout',
  });
});

test('probeUrl timeout does not depend on a stalled arrayBuffer honoring AbortSignal', async () => {
  const probe = probeUrl('https://cdn.example.test/movie.mp4', {
    timeoutMs: 10,
    fetchImpl: async (url, init) => {
      if (init.method === 'HEAD') return { status: 200, url: String(url), headers: new Headers({ 'content-type': 'video/mp4' }) };
      return {
        status: 206,
        url: String(url),
        headers: new Headers({ 'content-type': 'video/mp4' }),
        body: null,
        arrayBuffer: () => new Promise(() => {}),
      };
    },
  });
  const result = await Promise.race([
    probe,
    new Promise((resolve) => setTimeout(() => resolve('hung'), 50)),
  ]);
  assert.notEqual(result, 'hung');
  assert.equal(result.conclusive, false);
  assert.equal(result.detail, 'timeout');
});

test('ambiguous HTTP responses from an HLS variant remain inconclusive', async () => {
  for (const status of [401, 403, 405, 429, 503]) {
    let call = 0;
    const result = await probeUrl('https://cdn.example.test/master.m3u8', {
      fetchImpl: async (url, init) => {
        call += 1;
        if (init.method === 'HEAD') return mockResponse(200, 'application/vnd.apple.mpegurl', '', String(url));
        if (call === 2) return mockResponse(200, 'application/vnd.apple.mpegurl', '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1\nvariant.m3u8', String(url));
        return mockResponse(status, 'text/plain', 'blocked', String(url));
      },
    });
    assert.equal(result.conclusive, false, `status ${status}`);
    assert.equal(result.reason, 'blocked-or-unknown', `status ${status}`);
    assert.equal(result.httpCode, status, `status ${status}`);
  }
});

test('ambiguous HTTP responses from an HLS segment remain inconclusive', async () => {
  for (const status of [401, 403, 405, 429, 503]) {
    let call = 0;
    const result = await probeUrl('https://cdn.example.test/live.m3u8', {
      fetchImpl: async (url, init) => {
        call += 1;
        if (init.method === 'HEAD') return mockResponse(200, 'application/vnd.apple.mpegurl', '', String(url));
        if (call === 2) return mockResponse(200, 'application/vnd.apple.mpegurl', '#EXTM3U\n#EXTINF:4,\nsegment.ts', String(url));
        return mockResponse(status, 'text/plain', 'blocked', String(url));
      },
    });
    assert.equal(result.conclusive, false, `status ${status}`);
    assert.equal(result.reason, 'blocked-or-unknown', `status ${status}`);
    assert.equal(result.httpCode, status, `status ${status}`);
  }
});

test('redirect cookies obey host, path, Secure and expiry scope', async () => {
  const calls = [];
  const transportStream = Buffer.alloc(377);
  transportStream[0] = 0x47;
  transportStream[188] = 0x47;
  const result = await probeUrl('https://origin.example.test/start', {
    fetchImpl: async (url, init) => {
      const target = String(url);
      calls.push({ target, headers: init.headers, method: init.method, redirect: init.redirect });
      if (init.method === 'HEAD') return mockResponse(200, 'text/plain', '', target);
      if (target === 'https://origin.example.test/start') {
        return mockResponse(302, 'text/plain', '', target, {
          location: 'https://media.example.test/live/master.m3u8',
          'set-cookie': 'origin_secret=one; Path=/private; Secure',
        });
      }
      if (target.endsWith('/live/master.m3u8')) {
        const response = mockResponse(200, 'application/vnd.apple.mpegurl', '#EXTM3U\n#EXTINF:4,\nsegments/part.ts', target);
        response.headers = {
          get: (name) => name.toLowerCase() === 'content-type' ? 'application/vnd.apple.mpegurl' : null,
          getSetCookie: () => [
            'media_session=two; Path=/live; Secure',
            'expired_session=gone; Path=/live; Expires=Wed, 01 Jan 2020 00:00:00 GMT',
          ],
        };
        return response;
      }
      if (target === 'https://media.example.test/live/segments/part.ts') {
        return mockResponse(302, 'text/plain', '', target, { location: 'http://media.example.test/live/final.ts' });
      }
      return mockResponse(206, 'video/mp2t', transportStream, target);
    },
  });
  assert.equal(result.ok, true);
  const redirected = calls.find((call) => call.target === 'https://media.example.test/live/master.m3u8');
  const segment = calls.find((call) => call.target === 'https://media.example.test/live/segments/part.ts');
  const insecureFinal = calls.find((call) => call.target === 'http://media.example.test/live/final.ts');
  assert.equal(redirected.redirect, 'manual');
  assert.equal(redirected.headers.Cookie, undefined);
  assert.equal(segment.headers.Cookie, 'media_session=two');
  assert.doesNotMatch(segment.headers.Cookie, /origin_secret/);
  assert.doesNotMatch(segment.headers.Cookie, /expired_session/);
  assert.equal(insecureFinal.headers.Cookie, undefined);
});

function mockResponse(status, type, body, url, extraHeaders = {}) {
  return {
    status,
    url,
    headers: new Headers({ 'content-type': type, ...extraHeaders }),
    body: new Response(body).body,
  };
}
