'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const artwork = require('./episode-artwork');
const html = fs.readFileSync(require.resolve('./index.html'), 'utf8');
function block(start, end){return html.slice(html.indexOf(start), html.indexOf(end, html.indexOf(start)));}
function fixture(seasonNumber = '1'){
  const servers = [{url: 'https://stream.example/one', language: 'es'}];
  const original = {id: 'ep', number: 1, plot: 'Keep me', duration: '45 min', poster: 'https://old/cover', servers};
  const fields = {'.nm': {value: '1'}, '.t': {value: 'Episode'}, '.ep-poster': {value: original.poster},
    '.episode-servers': {}, '.ep-preview': {removeAttribute(){}}, '.ep-empty': {}};
  const row = {isConnected: true, dataset: {metadata: JSON.stringify(artwork.metadata(original))}, querySelector: key => fields[key]};
  const snum = {value: seasonNumber};
  const section = {querySelector: () => snum, querySelectorAll: () => [row]};
  const root = {querySelectorAll: () => [section]};
  const elements = {f_seasons: root, overlay: {classList: {contains: () => true}}, tmdb_results: {},
    f_title: {value: 'Series'}, f_content_type: {value: 'series'}, f_tmdb_id: {value: '123'}, f_tmdb_type: {value: 'tv'},
    'episode-artwork-refresh': {}, 'episode-artwork-state': {}, tmdb_state: {}, f_categories: {}};
  for(const element of Object.values(elements)){
    element.dispatchEvent=()=>{};
    if('value' in element){
      let value=String(element.value);
      Object.defineProperty(element,'value',{get:()=>value,set:next=>{value=String(next);}});
    }
  }
  const document = {getElementById: id => elements[id] || null, querySelectorAll: selector =>
    selector.endsWith('.ep-poster') ? [fields['.ep-poster']] : selector.endsWith('.snum') ? [snum] : [section]};
  const toasts = [];
  const context = vm.createContext({EpisodeArtwork: artwork, document, window: {}, Event: class{},
    catalog: {series: [{id: 'series-id'}], movies: []}, activeTab: 'series',
    collectServers: () => servers, hasMissingLanguage: () => false, collectCategories: () => [],
    classify: () => [], registerNewCategories(){}, categoryChips: () => '',
    uid: () => 'unused', save(){}, render(){}, closeModal(){}, languageGroups: () => '',
    toast: (message, type) => toasts.push({message, type})});
  vm.runInContext(html.match(/function esc\(s\)\{[^\n]*\}/)[0], context);
  vm.runInContext(block('function fill(id,value)', '\nasync function syncTrending'), context);
  vm.runInContext(block('function seasonsBlock(it)', '\nwindow._epRow'), context);
  vm.runInContext(block('let episodeArtworkRequest=', 'async function saveAndPublish'), context);
  context.isTrending = async () => false;
  return {context, fields, snum, toasts, servers, elements};
}

test('actual admin save retains season zero, artwork and untouched episode metadata/servers', () => {
  const {context, fields, servers} = fixture('0');
  fields['.ep-poster'].value = 'https://image.tmdb.org/t/p/w300/exact.jpg';
  assert.equal(context.saveItem(0), true);
  const season = context.catalog.series[0].seasons[0];
  assert.equal(season.number, 0);
  assert.equal(season.episodes[0].poster, fields['.ep-poster'].value);
  assert.equal(season.episodes[0].plot, 'Keep me');
  assert.deepEqual(season.episodes[0].servers, servers);
});

test('actual save persists explicit removal, and rejects invalid image URLs without changing catalog', () => {
  const {context, fields, toasts} = fixture();
  fields['.ep-poster'].value = 'javascript:alert(1)';
  assert.equal(context.saveItem(0), undefined);
  assert.equal(context.catalog.series[0].seasons, undefined);
  assert.equal(toasts.at(-1).type, 'err');
  fields['.ep-poster'].value = '';
  assert.equal(context.saveItem(0), true);
  assert.equal(context.catalog.series[0].seasons[0].episodes[0].poster, null);
});

test('actual TMDB selection preserves image manually edited while detail is pending', async () => {
  const {context, fields, elements, toasts} = fixture();
  let release;
  const requests = [];
  context.tmdbApi = params => {
    requests.push(params);
    return params.startsWith('action=detail') ? new Promise(resolve => {release = resolve;}) :
      Promise.resolve({seasonNumber: 1, episodes: [{number: 1, poster: 'https://image.tmdb.org/t/p/w300/tmdb.jpg'}]});
  };
  const pending = context.tmdbPick('tv', 123);
  fields['.ep-poster'].value = 'https://manual/still.jpg';
  release({tmdbId: 123, tmdbType: 'tv', title: 'Series'});
  await pending;
  assert.equal(fields['.ep-poster'].value, 'https://manual/still.jpg');
  assert.ok(requests.some(value => value.startsWith('action=season')));
  assert.ok(elements['episode-artwork-state'].textContent.includes('1 sin coincidencia o editadas'));
  assert.ok(toasts.some(value => value.message === 'Miniaturas listas para guardar y publicar'));
  assert.ok(!elements.tmdb_results.innerHTML.includes('color:var(--accent)'));
});

test('episode form safely escapes metadata and uses a landscape preview', () => {
  const {context} = fixture();
  const markup = context.epHtml({number: 1, title: '"<script>', poster: 'https://example/image.jpg', servers: []});
  assert.ok(markup.includes('class="ep-preview"'));
  assert.ok(markup.includes('class="ep-poster"'));
  assert.ok(!markup.includes('"<script>'));
  assert.ok(markup.includes('&lt;script&gt;'));
});

test('all inline scripts in the admin remain syntactically valid', () => {
  for(const match of html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g))new vm.Script(match[1]);
});
