const test = require('node:test');
const assert = require('node:assert/strict');
const { extractOriginCandidates, refreshSourceFromOrigin } = require('./source-origin-refresh');

test('extracts safe HTTPS server links from the original page', () => {
  const candidates = extractOriginCandidates(
    '<a href="https://voe.sx/e/new-server">Voe</a><iframe src="https://example.com/ad"></iframe><a href="http://bad.test/x">bad</a>',
    'https://catalog.test/movie/pride',
  );
  assert.deepEqual(candidates, ['https://voe.sx/e/new-server', 'https://example.com/ad']);
});

test('refreshes a failed source from a new server published on its origin page', async () => {
  const source = {
    url: 'https://voe.sx/e/old-server',
    name: 'Voe',
    referer_url: 'https://catalog.test/movie/pride',
  };
  const fetchImpl = async () => ({
    ok: true,
    status: 200,
    url: source.referer_url,
    text: async () => '<a href="https://voe.sx/e/new-server">Servidor renovado</a>',
  });
  const result = await refreshSourceFromOrigin(source, {
    fetchImpl,
    probe: async (url) => ({ ok: url.endsWith('/new-server'), conclusive: true, reason: 'media' }),
  });
  assert.equal(result.recovered, true);
  assert.equal(result.url, 'https://voe.sx/e/new-server');
  assert.equal(result.originUrl, source.referer_url);
});

test('does not use an unsafe origin page', async () => {
  const result = await refreshSourceFromOrigin({ url: 'https://voe.sx/e/old', referer_url: 'http://localhost/page' });
  assert.equal(result.attempted, false);
  assert.equal(result.reason, 'no-safe-origin-page');
});
