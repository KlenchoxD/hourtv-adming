'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const handler = require('./api/tmdb');
function response() {
  return {code: 200, setHeader(){}, status(code){this.code = code; return this;}, json(body){this.body = body; return this;}};
}
test('season API supplies episode-specific stills and explicit null without using series cover', async t => {
  const old = process.env.TMDB_KEY;
  process.env.TMDB_KEY = 'test-key';
  t.after(() => {if(old === undefined)delete process.env.TMDB_KEY; else process.env.TMDB_KEY = old;});
  t.mock.method(globalThis, 'fetch', async url => {
    assert.match(url, /\/tv\/123\/season\/2\?/);
    return {ok: true, json: async () => ({season_number: 2, poster_path: '/cover.jpg', episodes: [
      {episode_number: 1, still_path: '/one.jpg'}, {episode_number: 2, still_path: null}]})};
  });
  const res = response();
  await handler({query: {action: 'season', id: '123', season: '2'}}, res);
  assert.equal(res.code, 200);
  assert.deepEqual(res.body, {seasonNumber: 2, episodes: [
    {number: 1, poster: 'https://image.tmdb.org/t/p/w300/one.jpg'}, {number: 2, poster: null}]});
});
test('season API validates integer path parameters, supports specials and reports upstream failures', async t => {
  const old = process.env.TMDB_KEY; process.env.TMDB_KEY = 'test-key';
  t.after(() => {if(old === undefined)delete process.env.TMDB_KEY; else process.env.TMDB_KEY = old;});
  let calls = 0;
  t.mock.method(globalThis, 'fetch', async () => {calls++; return {ok: false, status: 404};});
  for (const [id, season] of [['../1', '1'], ['1', '-1'], ['1', 'x'], ['0', '1'], ['1', '1.5']]) {
    const res = response(); await handler({query: {action: 'season', id, season}}, res);
    assert.equal(res.code, 400);
  }
  assert.equal(calls, 0);
  const res = response(); await handler({query: {action: 'season', id: '1', season: '0'}}, res);
  assert.equal(res.code, 502);
  assert.equal(calls, 1);
});
