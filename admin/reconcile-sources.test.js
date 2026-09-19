const { test } = require('node:test');
const assert = require('node:assert');
const { reconcile, isUUIDv4 } = require('./reconcile-sources');
const cp = require('child_process');
const path = require('path');
const fs = require('fs');
const os = require('os');
const crypto = require('crypto');

const validUUID = '550e8400-e29b-41d4-a716-446655440000';
const validUUID2 = '660e8400-e29b-41d4-a716-446655440000';

test('validates UUIDv4 strictly', () => {
  assert.ok(isUUIDv4(validUUID));
  assert.strictEqual(isUUIDv4('1234'), false);
  assert.strictEqual(isUUIDv4('550e8400-e29b-11d4-a716-446655440000'), false); // v1
  assert.strictEqual(isUUIDv4(undefined), false);
});

test('returns 0 conflicts for empty catalog', () => {
  const catalog = { movies: [], series: [], liveChannels: [], sources: [] };
  const snapshot = { _metadata: { authority: 'authoritative' }, data: [] };
  const result = reconcile(catalog, snapshot);
  assert.strictEqual(result.conflicts.length, 0);
  assert.strictEqual(result.totalProposedChanges, 0);
});

test('ID 1234 rejected as invalid UUID', () => {
  const catalog = {
    movies: [
      { servers: [ { id: '1234', name: 'S1', url: 'http://a' } ] }
    ]
  };
  const result = reconcile(catalog, []);
  assert.strictEqual(result.invalidId, 1);
  assert.strictEqual(result.conflicts.length, 1);
  assert.match(result.conflicts[0], /Legacy\/Invalid ID '1234'/);
});

test('single match with Supabase UUID via URL (secondary discriminator)', () => {
  const catalog = {
    movies: [
      { id: 'movie-1', servers: [ { name: 'S1', url: 'http://a' } ] }
    ]
  };
  const snapshot = {
    _metadata: { authority: 'authoritative' },
    data: [
      { id: validUUID, url: 'http://a', name: 'S1', titles: { media_type: 'movie', legacy_id: 'movie-1' } }
    ]
  };
  const result = reconcile(catalog, snapshot);
  assert.strictEqual(result.matched, 1);
  assert.strictEqual(result.new, 0);
  assert.strictEqual(result.ambiguous, 0);
  assert.strictEqual(result.totalProposedChanges, 1);
  assert.strictEqual(result.conflicts.length, 0);
});

test('confirmedLocal UUID when local UUID exists in snapshot', () => {
  const catalog = {
    movies: [
      { id: 'movie-1', servers: [ { id: validUUID, name: 'S1', url: 'http://a' } ] }
    ]
  };
  const snapshot = {
    _metadata: { authority: 'authoritative' },
    data: [
      { id: validUUID, url: 'http://a', name: 'S1', titles: { media_type: 'movie', legacy_id: 'movie-1' } }
    ]
  };
  const result = reconcile(catalog, snapshot);
  assert.strictEqual(result.matched, 1);
  assert.strictEqual(result.confirmedLocal, 1);
  assert.strictEqual(result.unmatched, 0);
  assert.strictEqual(result.totalProposedChanges, 0);
});

test('unmatched UUID when local UUID NOT found in snapshot', () => {
  const catalog = {
    movies: [
      { id: 'movie-1', servers: [ { id: validUUID, name: 'S1', url: 'http://a' } ] }
    ]
  };
  const snapshot = { _metadata: { authority: 'authoritative' }, data: [] };
  const result = reconcile(catalog, snapshot);
  assert.strictEqual(result.matched, 0);
  assert.strictEqual(result.confirmedLocal, 0);
  assert.strictEqual(result.unmatched, 1);
  assert.strictEqual(result.conflicts.length, 1);
  assert.match(result.conflicts[0], /not found in Supabase snapshot/);
});

test('non-empty RLS-limited snapshot marks absent items as unmatched, not new', () => {
  const catalog = {
    movies: [
      { id: 'movie-1', servers: [ { name: 'S1', url: 'http://a' } ] }
    ]
  };
  const snapshot = {
    _metadata: { type: 'RLS-limited snapshot', authority: 'rls-limited' },
    data: [ { id: validUUID, url: 'http://b', titles: { media_type: 'movie', legacy_id: 'movie-2' } } ]
  };
  const result = reconcile(catalog, snapshot);
  assert.strictEqual(result.matched, 0);
  assert.strictEqual(result.new, 0);
  assert.strictEqual(result.unmatched, 1); // fallback to unmatched instead of new
  assert.strictEqual(result.totalProposedChanges, 0);
});

test('snapshot without metadata marks absent items as unmatched, not new', () => {
  const catalog = {
    movies: [
      { id: 'movie-1', servers: [ { name: 'S1', url: 'http://a' } ] }
    ]
  };
  const snapshot = [ { id: validUUID, url: 'http://b', titles: { media_type: 'movie', legacy_id: 'movie-2' } } ]; // Array without metadata
  const result = reconcile(catalog, snapshot);
  assert.strictEqual(result.matched, 0);
  assert.strictEqual(result.new, 0);
  assert.strictEqual(result.unmatched, 1);
});

test('empty authoritative snapshot classifies absent sources as new', () => {
  const catalog = {
    movies: [
      { id: 'movie-1', servers: [ { name: 'S1', url: 'http://a' } ] }
    ]
  };
  const snapshot = {
    _metadata: { authority: 'authoritative' },
    data: []
  };
  const result = reconcile(catalog, snapshot);
  assert.strictEqual(result.matched, 0);
  assert.strictEqual(result.new, 1);
  assert.strictEqual(result.unmatched, 0);
  assert.strictEqual(result.totalProposedChanges, 1);
});

test('ambiguous match by URL', () => {
  const catalog = {
    movies: [
      { id: 'movie-1', servers: [ { name: 'S1', url: 'http://a' } ] }
    ]
  };
  const snapshot = {
    _metadata: { authority: 'authoritative' },
    data: [
      { id: validUUID, url: 'http://a', name: 'S1', titles: { media_type: 'movie', legacy_id: 'movie-1' } },
      { id: validUUID2, url: 'http://a', name: 'S1', titles: { media_type: 'movie', legacy_id: 'movie-1' } }
    ]
  };
  const result = reconcile(catalog, snapshot);
  assert.strictEqual(result.ambiguous, 1);
  assert.strictEqual(result.conflicts.length, 1);
  assert.match(result.conflicts[0], /Ambiguous match/);
});

test('CLI tests in tmp directory', () => {
  const scriptPath = path.resolve(__dirname, 'reconcile-sources.js');
  
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'hourtv-test-'));
  const catPath = path.join(tmpDir, 'catalog.json');
  const snapPath = path.join(tmpDir, 'supabase_snapshot.json');
  
  try {
    // 1. Exit 0: clean
    fs.writeFileSync(catPath, JSON.stringify({ movies: [] }));
    fs.writeFileSync(snapPath, JSON.stringify({ _metadata: { authority: 'authoritative' }, data: [] }));
    let res = cp.spawnSync('node', [scriptPath, '--dry-run', '--catalog', catPath, '--supabase-snapshot', snapPath], { encoding: 'utf8' });
    assert.strictEqual(res.status, 0);

    // 2. Exit 2: safe changes proposed (authoritative missing match -> new)
    fs.writeFileSync(catPath, JSON.stringify({ movies: [ { id: 'm1', servers: [ { name: 'S1', url: 'http://a' } ] } ] }));
    fs.writeFileSync(snapPath, JSON.stringify({ _metadata: { authority: 'authoritative' }, data: [] }));
    res = cp.spawnSync('node', [scriptPath, '--dry-run', '--catalog', catPath, '--supabase-snapshot', snapPath], { encoding: 'utf8' });
    assert.strictEqual(res.status, 2);
    assert.match(res.stdout, /New UUIDs needed: 1/);

    // 3. Exit 3: unmatched item
    fs.writeFileSync(catPath, JSON.stringify({ movies: [ { id: 'm1', servers: [ { name: 'S1', url: 'http://a' } ] } ] }));
    fs.writeFileSync(snapPath, JSON.stringify({ _metadata: { authority: 'rls-limited' }, data: [] }));
    res = cp.spawnSync('node', [scriptPath, '--dry-run', '--catalog', catPath, '--supabase-snapshot', snapPath], { encoding: 'utf8' });
    assert.strictEqual(res.status, 3);
    assert.match(res.stderr, /ERROR: Unmatched sources detected/);
    assert.match(res.stdout, /Unmatched: 1/);

    // 4. Invalid JSON
    fs.writeFileSync(catPath, '{ invalid json }');
    res = cp.spawnSync('node', [scriptPath, '--dry-run', '--catalog', catPath, '--supabase-snapshot', snapPath], { encoding: 'utf8' });
    assert.strictEqual(res.status, 3);

  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
});

test('CLI preserves physical catalog byte-by-byte', () => {
  const scriptPath = path.resolve(__dirname, 'reconcile-sources.js');
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'hourtv-test-'));
  const catPath = path.join(tmpDir, 'catalog.json');
  const snapPath = path.join(tmpDir, 'supabase_snapshot.json');
  
  try {
    const rawCat = '{\n  "movies": []\n}';
    fs.writeFileSync(catPath, rawCat);
    fs.writeFileSync(snapPath, JSON.stringify({ _metadata: { authority: 'authoritative' }, data: [] }));
    
    const hashBefore = crypto.createHash('sha256').update(fs.readFileSync(catPath)).digest('hex');
    
    const res = cp.spawnSync('node', [scriptPath, '--dry-run', '--catalog', catPath, '--supabase-snapshot', snapPath], { encoding: 'utf8' });
    assert.strictEqual(res.status, 0);

    const hashAfter = crypto.createHash('sha256').update(fs.readFileSync(catPath)).digest('hex');
    assert.strictEqual(hashBefore, hashAfter);
    assert.strictEqual(fs.readFileSync(catPath, 'utf8'), rawCat);
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
});
