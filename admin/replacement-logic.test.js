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
  ];
  for (const item of cases) assert.equal(evaluateCandidate(episode, item, { now: NOW }).confidence, 'rejected');
});

test('evaluateCandidate grades incomplete and stale evidence below high', () => {
  assert.equal(
    evaluateCandidate({ type: 'movie', title: 'Unknown', language: 'es' }, candidate({ tmdbId: null, title: 'Unknown', year: null }), { now: NOW }).confidence,
    'low',
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

test('deduplicateCandidates canonicalizes URLs and retains the strongest candidate', () => {
  const result = deduplicateCandidates([
    { id: 'low', url: 'https://VIDEO.example/watch/?b=2&a=1#fragment', confidence: 'low', providerPriority: 1 },
    { id: 'high', url: 'https://video.example/watch?a=1&b=2', confidence: 'high', providerPriority: 9 },
    { id: 'other', url: 'https://video.example/watch/2', confidence: 'medium', providerPriority: 2 },
  ]);
  assert.deepEqual(result.map((item) => item.id), ['high', 'other']);
});

test('buildBatchSummary includes only fresh high candidates and explains exclusions', () => {
  const items = [
    { sourceId: 's1', ...candidate({ id: 'h', confidence: 'high' }) },
    { sourceId: 's2', ...candidate({ id: 'm', confidence: 'medium' }) },
    { sourceId: 's3', ...candidate({ id: 'stale', confidence: 'high', checkedAt: '2026-09-20T00:00:00.000Z' }) },
    { sourceId: 's1', ...candidate({ id: 'duplicate-source', confidence: 'high', url: 'https://video.example/other' }) },
  ];
  const summary = buildBatchSummary(items, { now: NOW });
  assert.deepEqual(summary.included.map((item) => item.id), ['h']);
  assert.equal(summary.excluded.length, 3);
  assert.deepEqual(summary.counts, { total: 4, included: 1, excluded: 3 });
  assert.deepEqual(summary.excluded.map((item) => item.exclusionReason), [
    'confidence_not_high', 'stale_validation', 'source_already_selected',
  ]);
});
