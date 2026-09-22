const test = require('node:test');
const assert = require('node:assert/strict');

const {
  AdapterRegistry,
  orderProviders,
  selectFallbackCandidate,
  searchWithFallback,
} = require('./index');

test('orderProviders returns active providers in stable priority order', () => {
  const providers = [
    { id: 'b', priority: 20, isActive: true },
    { id: 'off', priority: 1, isActive: false },
    { id: 'a2', priority: 10, isActive: true },
    { id: 'a1', priority: 10, isActive: true },
  ];

  assert.deepEqual(orderProviders(providers).map((item) => item.id), ['a2', 'a1', 'b']);
  assert.deepEqual(providers.map((item) => item.id), ['b', 'off', 'a2', 'a1']);
});

test('registry rejects adapters missing the common movie or episode contract', () => {
  const registry = new AdapterRegistry();
  assert.throws(
    () => registry.register('broken', { searchMovie() {} }),
    /searchMovie and searchEpisode/,
  );
});

test('selectFallbackCandidate purely chooses high confidence from the earliest provider', () => {
  const results = [
    { provider: { id: 'b', priority: 20, isActive: true }, candidates: [{ id: 'b-high', confidence: 'high' }] },
    { provider: { id: 'a', priority: 10, isActive: true }, candidates: [{ id: 'a-low', confidence: 'low' }, { id: 'a-high', confidence: 'high' }] },
  ];
  assert.equal(selectFallbackCandidate(results).id, 'a-high');
  assert.equal(selectFallbackCandidate([{ provider: { id: 'a', priority: 1 }, candidates: [] }]), null);
  assert.equal(results[0].provider.id, 'b');
});

test('searchWithFallback tries providers by priority and stops at the first high candidate', async () => {
  const registry = new AdapterRegistry();
  const calls = [];
  registry.register('page-a', {
    async searchMovie() { calls.push('A'); return [{ id: 'medium', type: 'movie', tmdbId: 42, title: 'Example', year: 2026, language: null, url: 'https://video.example/a', reproducible: true, checkedAt: '2026-09-22T11:00:00Z' }]; },
    async searchEpisode() { return []; },
  });
  registry.register('page-b', {
    async searchMovie() { calls.push('B'); return [{ id: 'high', type: 'movie', tmdbId: 42, title: 'Example', year: 2026, language: 'es', url: 'https://video.example/b', reproducible: true, checkedAt: '2026-09-22T11:00:00Z' }]; },
    async searchEpisode() { return []; },
  });
  registry.register('page-c', {
    async searchMovie() { calls.push('C'); return [{ id: 'never' }]; },
    async searchEpisode() { return []; },
  });

  const result = await searchWithFallback({
    providers: [
      { id: 'c', adapterName: 'page-c', priority: 30, isActive: true },
      { id: 'b', adapterName: 'page-b', priority: 20, isActive: true },
      { id: 'a', adapterName: 'page-a', priority: 10, isActive: true },
    ],
    registry,
    kind: 'movie',
    query: { type: 'movie', tmdbId: 42, title: 'Example', year: 2026, language: 'es' },
    now: new Date('2026-09-22T12:00:00Z'),
  });

  assert.deepEqual(calls, ['A', 'B']);
  assert.equal(result.candidate.id, 'high');
  assert.deepEqual(result.attempts.map((attempt) => attempt.providerId), ['a', 'b']);
});

test('searchWithFallback records unsupported adapters and continues', async () => {
  const registry = new AdapterRegistry();
  registry.register('ready', {
    async searchMovie() { return []; },
    async searchEpisode() { return []; },
  });

  const result = await searchWithFallback({
    providers: [
      { id: 'template', adapterName: 'missing', priority: 1, isActive: true },
      { id: 'ready', adapterName: 'ready', priority: 2, isActive: true },
    ],
    registry,
    kind: 'episode',
    query: { type: 'episode', tmdbId: 5, seriesTitle: 'Series', year: 2025, season: 1, episode: 2, language: 'es' },
  });

  assert.equal(result.candidate, null);
  assert.equal(result.attempts[0].reason, 'adapter_not_registered');
  assert.equal(result.attempts[1].reason, 'no_candidates');
});

test('searchWithFallback rejects malformed adapter results and unsafe high claims', async () => {
  const registry = new AdapterRegistry();
  registry.register('malformed', {
    async searchMovie() { return { confidence: 'high' }; },
    async searchEpisode() { return []; },
  });
  registry.register('unsafe', {
    async searchMovie() { return [{ id: 'fake', confidence: 'high', type: 'movie', tmdbId: 999, title: 'Example', year: 2026, language: 'es', url: 'https://video.example/1', reproducible: true, checkedAt: '2026-09-22T11:00:00Z' }]; },
    async searchEpisode() { return []; },
  });
  const result = await searchWithFallback({
    providers: [
      { id: 'malformed', adapterName: 'malformed', priority: 1 },
      { id: 'unsafe', adapterName: 'unsafe', priority: 2 },
    ],
    registry,
    kind: 'movie',
    query: { type: 'movie', tmdbId: 42, title: 'Example', year: 2026, language: 'es' },
    now: new Date('2026-09-22T12:00:00Z'),
  });
  assert.equal(result.candidate, null);
  assert.equal(result.attempts[0].reason, 'validator_error');
  assert.equal(result.attempts[1].reason, 'no_high_candidate');
});

test('searchWithFallback distinguishes adapter exceptions from validator errors', async () => {
  const registry = new AdapterRegistry();
  registry.register('throws', {
    async searchMovie() { throw new Error('provider offline'); },
    async searchEpisode() { return []; },
  });
  const result = await searchWithFallback({
    providers: [{ id: 'throws', adapterName: 'throws', priority: 1 }],
    registry,
    kind: 'movie',
    query: { type: 'movie', tmdbId: 42, title: 'Example', year: 2026, language: 'es' },
  });
  assert.equal(result.attempts[0].reason, 'adapter_error');
});
