'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  locateCatalogSource,
  replaceCatalogSource,
  reorderProviders,
  persistProviderOrder,
  applyReplacement,
  applyReplacementBatch,
} = require('./replacement-admin');

function fixture() {
  return {
    version: 2,
    movies: [{ id: 'movie-1', title: 'Una película', tmdbId: 10, servers: [
      { id: 'source-a', name: 'VOE', url: 'https://old.example/a', language: 'Español' },
      { id: 'source-b', name: 'Otro', url: 'https://keep.example/b', language: 'Español' },
    ] }],
    series: [{ id: 'series-1', title: 'Una serie', tmdbId: 20, seasons: [{ number: 2, episodes: [
      { number: 3, title: 'Tres', servers: [{ id: 'source-c', name: 'Viejo', url: 'https://old.example/c', language: 'Latino' }] },
    ] }] }],
    sources: [],
  };
}

test('locates a source exactly in a movie or episode', () => {
  const catalog = fixture();
  assert.deepEqual(locateCatalogSource(catalog, { sourceId: 'source-a', contentType: 'movie', tmdbId: 10 }).path, ['movies', 0, 'servers', 0]);
  assert.deepEqual(locateCatalogSource(catalog, { sourceId: 'source-c', contentType: 'episode', tmdbId: 20, season: 2, episode: 3 }).path,
    ['series', 0, 'seasons', 0, 'episodes', 0, 'servers', 0]);
  assert.equal(locateCatalogSource(catalog, { sourceId: 'source-c', contentType: 'episode', tmdbId: 20, season: 2, episode: 4 }), null);
});

test('replaces while preserving language, name, id and order and rejects duplicate URLs', () => {
  const catalog = fixture();
  const changed = replaceCatalogSource(catalog, {
    sourceId: 'source-a', contentType: 'movie', tmdbId: 10,
    url: 'https://new.example/a', proposedName: '', candidateId: 'candidate-1',
  });
  assert.deepEqual(changed.next, {
    id: 'source-a', name: 'VOE', url: 'https://new.example/a', language: 'Español',
    replacement: { candidateId: 'candidate-1', previousUrl: 'https://old.example/a' },
  });
  assert.equal(catalog.movies[0].servers[0].url, 'https://new.example/a');
  assert.throws(() => replaceCatalogSource(catalog, {
    sourceId: 'source-a', contentType: 'movie', tmdbId: 10, url: 'https://keep.example/b',
  }), /ya existe/i);
});

test('provider reorder is immutable and creates consecutive safe priorities', () => {
  const providers = [{ id: 'a', priority: 10 }, { id: 'b', priority: 20 }, { id: 'c', priority: 30 }];
  assert.deepEqual(reorderProviders(providers, 'c', -1).map(p => [p.id, p.priority]), [['a', 0], ['c', 1], ['b', 2]]);
  assert.deepEqual(providers.map(p => p.priority), [10, 20, 30]);
});

test('provider order persists through collision-free temporary priorities', async () => {
  const writes = [];
  const providers = [{ id:'b', priority:1 }, { id:'a', priority:0 }];
  const result = await persistProviderOrder(providers, async (id, patch) => writes.push([id, patch.priority]));
  assert.deepEqual(result.map(item => [item.id, item.priority]), [['a',0],['b',1]]);
  assert.equal(writes.length, 4);
  assert.ok(writes.slice(0,2).every(([, priority]) => priority > 1));
  assert.deepEqual(writes.slice(2), [['a',0],['b',1]]);
});

test('individual replacement revalidates stale candidates and persists audit state', async () => {
  const catalog = fixture();
  const calls = [];
  await applyReplacement({
    catalog,
    candidate: { id: 'candidate-1', sourceId: 'source-a', contentType: 'movie', tmdbId: 10, url: 'https://new.example/a', expiresAt: '2020-01-01' },
    now: new Date('2026-01-01'),
    revalidate: async candidate => ({ ...candidate, expiresAt: '2026-01-02', confidence: 'high' }),
    persist: async payload => calls.push(['persist', payload.next.url]),
    markPending: async () => calls.push(['pending']),
  });
  assert.equal(catalog.movies[0].servers[0].url, 'https://new.example/a');
  assert.deepEqual(calls, [['persist', 'https://new.example/a'], ['pending']]);
});

test('batch publishes once and rolls back all local replacements on apply failure', async () => {
  const catalog = fixture();
  let publications = 0;
  const candidates = [
    { id: 'one', sourceId: 'source-a', contentType: 'movie', tmdbId: 10, title: 'Una película', language: 'Español', reproducible: true, url: 'https://new.example/a', checkedAt: '2026-01-01T00:00:00Z', expiresAt: '2026-01-03T00:00:00Z', confidence: 'high' },
    { id: 'two', sourceId: 'source-c', contentType: 'episode', tmdbId: 20, seriesTitle: 'Una serie', season: 2, episode: 3, language: 'Latino', reproducible: true, url: 'https://new.example/c', checkedAt: '2026-01-01T00:00:00Z', expiresAt: '2026-01-03T00:00:00Z', confidence: 'high' },
  ];
  const targetsBySource = {
    'source-a': { type: 'movie', tmdbId: 10, title: 'Una película', language: 'Español' },
    'source-c': { type: 'episode', tmdbId: 20, seriesTitle: 'Una serie', season: 2, episode: 3, language: 'Latino' },
  };
  await assert.rejects(applyReplacementBatch({ catalog, candidates, targetsBySource, now: new Date('2026-01-02'),
    persist: async ({ candidate }) => { if (candidate.id === 'two') throw new Error('falló persistencia'); },
    publish: async () => { publications += 1; },
  }), /falló persistencia/);
  assert.equal(catalog.movies[0].servers[0].url, 'https://old.example/a');
  assert.equal(catalog.series[0].seasons[0].episodes[0].servers[0].url, 'https://old.example/c');
  assert.equal(publications, 0);
});

test('batch excludes non-high candidates and publishes exactly once', async () => {
  const catalog = fixture();
  let publications = 0;
  const high = { id: 'one', sourceId: 'source-a', contentType: 'movie', tmdbId: 10, title: 'Una película', language: 'Español', reproducible: true, url: 'https://new.example/a', checkedAt: '2026-01-01T00:00:00Z', expiresAt: '2026-01-03T00:00:00Z', confidence: 'high' };
  const medium = { ...high, id: 'two', sourceId: 'source-b', checkedAt: '2020-01-01', expiresAt: '2026-01-03T00:00:00Z' };
  const result = await applyReplacementBatch({ catalog, candidates: [high, medium], now: new Date('2026-01-02'),
    targetsBySource: {
      'source-a': { type: 'movie', tmdbId: 10, title: 'Una película', language: 'Español' },
      'source-b': { type: 'movie', tmdbId: 10, title: 'Una película', language: 'Español' },
    }, persist: async () => {}, publish: async () => { publications += 1; },
  });
  assert.equal(result.applied.length, 1);
  assert.equal(result.summary.excluded.length, 1);
  assert.equal(publications, 1);
});

test('publication failure keeps applied catalog changes pending for retry', async () => {
  const catalog = fixture();
  const high = { id:'one', sourceId:'source-a', contentType:'movie', tmdbId:10, title:'Una película', language:'Español', reproducible:true, url:'https://new.example/a', checkedAt:'2026-01-01T12:00:00Z', expiresAt:'2026-01-03T00:00:00Z' };
  const result = await applyReplacementBatch({ catalog, candidates:[high], now:new Date('2026-01-02'), targetsBySource:{ 'source-a':{ type:'movie', tmdbId:10, title:'Una película', language:'Español' } }, persist:async()=>{}, publish:async()=>{ throw new Error('GitHub no disponible'); } });
  assert.equal(catalog.movies[0].servers[0].url, 'https://new.example/a');
  assert.equal(result.pendingPublish, true);
  assert.match(result.publishError.message, /GitHub/);
});
