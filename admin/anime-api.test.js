"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const handler = require("./api/anime");

function createRes() {
  return {
    code: 200,
    headers: {},
    sent: null,
    body: null,
    ended: false,
    setHeader(name, value) {
      this.headers[name.toLowerCase()] = value;
    },
    status(code) {
      this.code = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
    send(payload) {
      this.sent = payload;
      return this;
    },
    end() {
      this.ended = true;
      return this;
    },
  };
}

test("anime API preserves FxxMorgan attribution header and serves health/config", async () => {
  const h = handler.createHandler({ env: {} });
  const resHealth = createRes();
  await h({ method: "GET", url: "/api/v1/anime/health", query: {} }, resHealth);
  assert.equal(resHealth.code, 200);
  assert.equal(resHealth.headers["x-powered-by"], "FxxMorgan (https://github.com/FxxMorgan)");
  assert.equal(resHealth.body.status, "ok");

  const resCfg = createRes();
  await h({ method: "GET", url: "/api/v1/anime/config", query: {} }, resCfg);
  assert.equal(resCfg.code, 200);
  assert.equal(resCfg.body.mode, "vercel-http");
  assert.equal(resCfg.body.publicBaseUrl, null);
});

test("anime API delegates catalog, search, info, episode and resolve cleanly", async () => {
  const stubService = {
    PROVIDERS: [{ id: "animeav1" }, { id: "tioanime" }],
    async getCatalog(page, genre, provider) {
      assert.equal(page, "2");
      assert.equal(genre, "accion");
      assert.equal(provider, "animeav1");
      return { success: true, data: { page: 2, results: [{ title: "Naruto", url: "https://animeav1.com/media/naruto" }], count: 1 } };
    },
    async searchAnime(q) {
      return { success: true, source: "Multi", data: { results: [{ title: q, url: "https://animeav1.com/media/naruto" }], count: 1 } };
    },
    async getAnimeInfo(url) {
      return { success: true, source: "animeav1", data: { title: "Naruto", url, episodes: [{ number: 1, url: `${url}/1` }] } };
    },
    async getEpisodeLinks(url) {
      return { success: true, source: "animeav1", data: { streamLinks: { SUB: [{ server: "HLS", url: "https://player.zilla-networks.com/play/abc12345" }] } } };
    },
  };
  const h = handler.createHandler({
    env: {},
    animeService: stubService,
    async resolveEmbed(url) {
      if (url.includes("zilla-networks")) {
        return {
          server: "zilla",
          mediaType: "hls",
          streamUrl: "https://player.zilla-networks.com/m3u8/abc12345",
          headers: { Referer: "https://player.zilla-networks.com/" },
        };
      }
      return null;
    },
  });

  const catRes = createRes();
  await h({ method: "GET", url: "/api/v1/anime/catalog", query: { provider: "animeav1", page: "2", genre: "accion" } }, catRes);
  assert.equal(catRes.code, 200);
  assert.equal(catRes.body.data.results[0].title, "Naruto");

  const searchRes = createRes();
  await h({ method: "GET", url: "/api/v1/anime/search", query: { q: "naruto" } }, searchRes);
  assert.equal(searchRes.code, 200);
  assert.equal(searchRes.body.data.count, 1);

  const resolveRes = createRes();
  await h({ method: "GET", query: { endpoint: "resolve", url: "https://player.zilla-networks.com/play/abc12345" } }, resolveRes);
  assert.equal(resolveRes.code, 200);
  assert.equal(resolveRes.body.mediaType, "hls");
  assert.equal(resolveRes.body.streamUrl, "https://player.zilla-networks.com/m3u8/abc12345");
  assert.deepEqual(resolveRes.body.headers, { Referer: "https://player.zilla-networks.com/" });
});

test("anime API forwards to ANIME1V_UPSTREAM_URL when configured and rejects private SSRF URLs", async () => {
  const ssrfRes = createRes();
  const localHandler = handler.createHandler({ env: {} });
  await localHandler({ method: "GET", query: { endpoint: "info", url: "http://127.0.0.1:8080/secret" } }, ssrfRes);
  assert.equal(ssrfRes.code, 400);

  const calls = [];
  const proxyHandler = handler.createHandler({
    env: {
      ANIME1V_UPSTREAM_URL: "https://anime.example.com/",
      ANIME1V_UPSTREAM_KEY: "secret-key",
      ANIME1V_PUBLIC_URL: "https://anime.example.com",
    },
    async fetchImpl(url, init) {
      calls.push({ url, headers: init.headers });
      return {
        status: 200,
        headers: new Map([["content-type", "application/json"]]),
        async text() {
          return JSON.stringify({ success: true, proxied: true });
        },
      };
    },
  });

  const cfgRes = createRes();
  await proxyHandler({ method: "GET", query: { endpoint: "config" } }, cfgRes);
  assert.equal(cfgRes.body.mode, "external");
  assert.equal(cfgRes.body.publicBaseUrl, "https://anime.example.com");

  const searchRes = createRes();
  await proxyHandler({ method: "GET", query: { endpoint: "search", q: "bleach" } }, searchRes);
  assert.equal(searchRes.code, 200);
  assert.equal(searchRes.body.proxied, true);
  assert.equal(calls[0].url, "https://anime.example.com/api/v1/anime/search?q=bleach");
  assert.equal(calls[0].headers["x-api-key"], "secret-key");
});

test("anime API returns 401 when ANIME1V_API_KEY is enabled and missing", async () => {
  const h = handler.createHandler({ env: { ANIME1V_API_KEY: "token-123" } });
  const unauthorized = createRes();
  await h({ method: "GET", headers: {}, query: { endpoint: "search", q: "one piece" } }, unauthorized);
  assert.equal(unauthorized.code, 401);
});
