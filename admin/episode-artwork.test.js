'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const artwork = require('./episode-artwork');

test('saving replaces legacy artwork, preserving episode metadata and servers', () => {
  const servers = [{url: 'https://stream.example/one', language: 'es'}];
  const original = {number: 1, title: 'Old', poster: 'https://old/series.jpg',
    backdrop: 'https://old/series.jpg', thumbnail: 'https://old/series.jpg',
    still_url: 'https://old/series.jpg', plot: 'Synopsis', duration: '45 min', id: 'ep-id'};
  const result = artwork.saveEpisode(original, {number: 2, title: 'New', servers,
    poster: 'https://image.tmdb.org/t/p/w300/episode.jpg'});
  assert.equal(result.poster, 'https://image.tmdb.org/t/p/w300/episode.jpg');
  assert.equal(result.plot, 'Synopsis');
  assert.equal(result.id, 'ep-id');
  assert.equal(result.duration, '45 min');
  assert.deepEqual(result.servers, servers);
  for (const key of ['backdrop', 'thumbnail', 'still_url']) assert.equal(key in result, false);
});

test('missing still clears the old cover explicitly and invalid URLs are rejected', () => {
  assert.equal(artwork.saveEpisode({poster: 'https://old/cover'}, {poster: '', servers: []}).poster, null);
  assert.throws(() => artwork.saveEpisode({}, {poster: 'javascript:alert(1)'}), /URL/);
});

function fixture(numbers, season = '1') {
  const rows = numbers.map(number => {
    const fields = {'.nm': {value: String(number)}, '.ep-poster': {value: 'https://old/cover'},
      '.ep-preview': {hidden: false, removeAttribute(){}}, '.ep-empty': {hidden: true}};
    return {fields, isConnected: true, querySelector: selector => fields[selector]};
  });
  const section = {querySelector: () => ({value: season}), querySelectorAll: () => rows};
  return {rows, root: {querySelectorAll: () => [section]}};
}

test('autofill matches episode numbers, clears missing stills, does not create episodes', async () => {
  const {root, rows} = fixture([3, 1, 2]);
  const result = await artwork.refresh(root, async number => {
    assert.equal(number, 1);
    return {seasonNumber: 1, episodes: [{number: 1, poster: 'https://image.tmdb.org/t/p/w300/one.jpg'},
      {number: 3, poster: 'https://image.tmdb.org/t/p/w300/three.jpg'}, {number: 2, poster: null}]};
  });
  assert.equal(rows[0].fields['.ep-poster'].value, 'https://image.tmdb.org/t/p/w300/three.jpg');
  assert.equal(rows[1].fields['.ep-poster'].value, 'https://image.tmdb.org/t/p/w300/one.jpg');
  assert.equal(rows[2].fields['.ep-poster'].value, '');
  assert.deepEqual({updated: result.updated, cleared: result.cleared, failures: result.failures},
    {updated: 2, cleared: 1, failures: []});
});

test('network errors or malformed season responses never erase artwork', async () => {
  for (const response of [() => {throw new Error('offline');}, () => ({seasonNumber: 2, episodes: []}), () => ({})]) {
    const {root, rows} = fixture([1]);
    const result = await artwork.refresh(root, response);
    assert.equal(rows[0].fields['.ep-poster'].value, 'https://old/cover');
    assert.equal(result.failures.length, 1);
  }
});

test('stale form and manual changes during fetch are not overwritten', async () => {
  const {root, rows} = fixture([1]);
  await artwork.refresh(root, async () => {
    rows[0].fields['.ep-poster'].value = 'https://manual/image.jpg';
    return {seasonNumber: 1, episodes: [{number: 1, poster: null}]};
  });
  assert.equal(rows[0].fields['.ep-poster'].value, 'https://manual/image.jpg');
  await artwork.refresh(root, async () => ({seasonNumber: 1, episodes: [{number: 1, poster: null}]}), () => false);
  assert.equal(rows[0].fields['.ep-poster'].value, 'https://manual/image.jpg');
});
