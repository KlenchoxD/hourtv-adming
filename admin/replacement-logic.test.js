const test = require('node:test');
const assert = require('node:assert/strict');

const {
  evaluateCandidate,
  deduplicateCandidates,
  buildBatchSummary,
} = require('./replacement-logic');

const NOW = new Date('2026-09-22T12:00:00.000Z');
const movie = {
  type: 'movie', tmdbId: 42, title: 'Amélie', year: 2001, language: 'es',
};

function candidate(overrides = {}) {
  return {
    id: 'candidate-1', type: 'movie', tmdbId: 42, title: 'Amelie', year: 2001,
    language: 'ES', url: 'https://video.example/embed/1', reproducible: true,
    checkedAt: '2026-09-22T11:00:00.000Z', providerPriority: 1,
    ...overrides,
  };
}

test('evaluateCandidate returns high for fresh reproducible exact movie identity', () => {
  const result = evaluateCandidate(movie, candidate(), { now: NOW });
  assert.equal(result.confidence, 'high');
  assert.equal(result.eligibleForBatch, true);
});

test('TMDB identity is mandatory when either side supplies it', () => {
  assert.equal(evaluateCandidate(movie, candidate({ tmdbId: null }), { now: NOW }).confidence, 'rejected');
  assert.equal(
    evaluateCandidate({ ...movie, tmdbId: null }, candidate({ tmdbId: 42 }), { now: NOW }).confidence,
    'rejected',
  );
  assert.equal(
    evaluateCandidate({ ...movie, tmdbId: null }, candidate({ tmdbId: null }), { now: NOW }).confidence,
    'high',
  );
});

test('evaluateCandidate rejects contradictory TMDB identity even when title matches', () => {
  const result = evaluateCandidate(movie, candidate({ tmdbId: 99 }), { now: NOW });
  assert.equal(result.confidence, 'rejected');
  assert.match(result.reasons.join(' '), /tmdb/i);
});

test('evaluateCandidate rejects wrong episode, language, type, or unplayable URL', () => {
  const episode = {
    type: 'episode', tmdbId: 77, title: 'The Show', year: 2024,
    season: 2, episode: 3, language: 'es',
  };
  const cases = [
    candidate({ type: 'movie', tmdbId: 77, title: 'The Show', year: 2024, season: 2, episode: 3 }),
    candidate({ type: 'episode', tmdbId: 77, title: 'The Show', year: 2024, season: 2, episode: 4 }),
    candidate({ type: 'episode', tmdbId: 77, title: 'The Show', year: 2024, season: 2, episode: 3, language: 'en' }),
    candidate({ type: 'episode', tmdbId: 77, title: 'The Show', year: 2024, season: 2, episode: 3, reproducible: false }),
    candidate({ type: 'episode', tmdbId: 77, title: 'Other Show', year: 2024, season: 2, episode: 3 }),
    candidate({ type: 'episode', tmdbId: 77, title: 'The Show', year: 2024, season: 2, episode: 3, url: 'https://127.0.0.1/video' }),
  ];
  for (const item of cases) assert.equal(evaluateCandidate(episode, item, { now: NOW }).confidence, 'rejected');
});

test('episode type aliases are normalized before series identity matching', () => {
  const target = { type: 'episode', tmdbId: 77, seriesTitle: 'The Show', year: 2024, season: 2, episode: 3, language: 'es' };
  const result = evaluateCandidate(target, candidate({ type: 'EPISODIO', tmdbId: 77, title: 'The Show', year: 2024, season: 2, episode: 3 }), { now: NOW });
  assert.equal(result.confidence, 'high');
  assert.equal(
    evaluateCandidate({ ...target, language: null }, candidate({ type: 'episode', tmdbId: 77, title: 'The Show', year: 2024, season: 2, episode: 3 }), { now: NOW }).confidence,
    'rejected',
  );
});

test('evaluateCandidate rejects incomplete identity and grades stale or partial evidence below high', () => {
  assert.equal(
    evaluateCandidate({ type: 'movie', title: 'Unknown', language: 'es' }, candidate({ tmdbId: null, title: 'Unknown', year: null }), { now: NOW }).confidence,
    'rejected',
  );
  assert.equal(
    evaluateCandidate(movie, candidate({ checkedAt: '2026-09-20T11:00:00.000Z' }), { now: NOW }).confidence,
    'medium',
  );
  assert.equal(
    evaluateCandidate(movie, candidate({ language: null }), { now: NOW }).confidence,
    'medium',
  );
  assert.equal(
    evaluateCandidate(movie, candidate({ type: null }), { now: NOW }).confidence,
    'rejected',
  );
});

test('deduplicateCandidates canonicalizes URLs and deduplicates by URL and source', () => {
  const result = deduplicateCandidates([
    { id: 'low', sourceId: 's1', url: 'https://VIDEO.example:443/watch/?b=2&a=1#fragment', confidence: 'low', providerPriority: 1 },
    { id: 'high', sourceId: 's2', url: 'https://video.example/watch?a=1&b=2', confidence: 'high', providerPriority: 9 },
    { id: 'same-source', sourceId: 's2', url: 'https://video.example/watch/2', confidence: 'medium', providerPriority: 2 },
    { id: 'other', sourceId: 's3', url: 'https://video.example/watch/3', confidence: 'medium', providerPriority: 2 },
  ]);
  assert.deepEqual(result.map((item) => item.id), ['high', 'other']);
});

test('buildBatchSummary reevaluates official target evidence and ignores stored confidence', () => {
  const items = [
    { sourceId: 's1', ...candidate({ id: 'h', confidence: 'rejected', expiresAt: '2026-09-23T00:00:00.000Z' }) },
    { sourceId: 's5', ...candidate({ id: 'duplicate-url', url: 'https://VIDEO.example:443/embed/1/#fragment', confidence: 'high', expiresAt: '2026-09-23T00:00:00.000Z' }) },
    { sourceId: 's2', ...candidate({ id: 'bad-tmdb', url: 'https://video.example/embed/2', tmdbId: 999, confidence: 'high', expiresAt: '2026-09-23T00:00:00.000Z' }) },
    { sourceId: 's3', ...candidate({ id: 'expired', url: 'https://video.example/embed/3', confidence: 'high', expiresAt: '2026-09-22T11:30:00.000Z' }) },
    { sourceId: 's4', ...candidate({ id: 'invalid-expiry', url: 'https://video.example/embed/4', confidence: 'high', expiresAt: 'not-a-date' }) },
    { sourceId: '', ...candidate({ id: 'missing-source', confidence: 'high', expiresAt: '2026-09-23T00:00:00.000Z' }) },
    { sourceId: 's1', ...candidate({ id: 'duplicate-source', confidence: 'high', url: 'https://video.example/other', expiresAt: '2026-09-23T00:00:00.000Z' }) },
  ];
  const targetsBySource = { s1: movie, s2: movie, s3: movie, s4: movie, s5: movie };
  const summary = buildBatchSummary(items, { now: NOW, targetsBySource });
  assert.deepEqual(summary.included.map((item) => item.id), ['h']);
  assert.equal(summary.included[0].confidence, 'high');
  assert.equal(summary.excluded.length, 6);
  assert.deepEqual(summary.counts, { total: 7, included: 1, excluded: 6 });
  assert.deepEqual(summary.excluded.map((item) => item.exclusionReason), [
    'url_already_selected', 'not_eligible', 'expired_validation', 'expired_validation', 'missing_source_id', 'source_already_selected',
  ]);
});
