// Adapted from FxxMorgan/anime1v-api (MIT) for HourTV Vercel HTTP runtime.
// Preserves FxxMorgan author attribution; excludes Puppeteer/FFmpeg providers.

const { URL } = require("node:url");
const { ApiError } = require("../utils/api-error");
const animeav1Service = require("./animeav1.service");
const tioanimeService = require("./tioanime.service");
const jkanimeService = require("./jkanime.service");
const monoschinosService = require("./monoschinos.service");

const DEFAULT_ANIME_DOMAIN = process.env.DEFAULT_ANIME_DOMAIN || "animeav1.com";
const MULTI_SEARCH_TIMEOUT_MS = Number(process.env.ANIME1V_MULTI_TIMEOUT_MS || 4500);

const PROVIDERS = [
  {
    id: "animeav1",
    label: "AnimeAV1",
    domains: [DEFAULT_ANIME_DOMAIN, "animeav1.com", "www.animeav1.com"],
    service: animeav1Service,
    includeInMultiSearch: true,
  },
  {
    id: "tioanime",
    label: "TioAnime",
    domains: ["tioanime.com", "www.tioanime.com"],
    service: tioanimeService,
    includeInMultiSearch: true,
  },
  {
    id: "jkanime",
    label: "JKAnime",
    domains: ["jkanime.net", "www.jkanime.net"],
    service: jkanimeService,
    includeInMultiSearch: false,
  },
  {
    id: "monoschinos",
    label: "MonosChinos",
    domains: ["monoschinos2.com", "www.monoschinos2.com", "monoschinos.st", "www.monoschinos.st"],
    service: monoschinosService,
    includeInMultiSearch: false,
  },
];

function withTimeout(promise, ms, label) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error(`${label} timeout (${ms}ms)`)), ms);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

function normalizeDomain(value) {
  if (!value || typeof value !== "string") return null;
  const trimmed = value.trim().toLowerCase();
  if (!trimmed) return null;
  try {
    if (trimmed.includes("://")) return new URL(trimmed).hostname.toLowerCase();
    return new URL(`https://${trimmed}`).hostname.toLowerCase();
  } catch (_error) {
    return trimmed.split("/")[0];
  }
}

function domainMatches(domain, candidate) {
  if (!domain || !candidate) return false;
  return domain === candidate || domain.endsWith(`.${candidate}`);
}

function findProviderByDomain(domainCandidate) {
  const domain = normalizeDomain(domainCandidate);
  if (!domain) return null;
  return PROVIDERS.find((p) => p.domains.some((c) => domainMatches(domain, c))) || null;
}

function findProviderById(providerId) {
  if (!providerId || typeof providerId !== "string") return null;
  const normalized = providerId.trim().toLowerCase();
  return PROVIDERS.find((p) => p.id === normalized) || null;
}

function findProviderForUrl(urlCandidate) {
  if (!urlCandidate || typeof urlCandidate !== "string") return null;
  try {
    return findProviderByDomain(new URL(urlCandidate).hostname);
  } catch (_error) {
    return null;
  }
}

function tagResults(results, providerLabel) {
  if (!Array.isArray(results)) return;
  for (const item of results) {
    item.provider = providerLabel;
    if (item.url) item.slug = item.url;
  }
}

async function getCatalog(page, genre, providerCandidate) {
  let provider = findProviderByDomain(providerCandidate) || findProviderById(providerCandidate) || PROVIDERS[0];
  if (typeof provider.service.getCatalog !== "function") {
    provider = PROVIDERS[0];
  }
  const response = await provider.service.getCatalog(page, genre);
  if (response && response.data && Array.isArray(response.data.results)) {
    tagResults(response.data.results, provider.label);
    for (const item of response.data.results) {
      item.provider = provider.id;
    }
  }
  return {
    ...response,
    source: response?.source || provider.id,
  };
}

async function searchAnime(query, domainCandidate) {
  const forcedProvider = findProviderByDomain(domainCandidate) || findProviderById(domainCandidate);
  if (forcedProvider) {
    const result = await forcedProvider.service.searchAnime(query, forcedProvider.domains[0]);
    tagResults(result?.data?.results, forcedProvider.label);
    return {
      ...result,
      source: result?.source || forcedProvider.id,
    };
  }

  const activeProviders = PROVIDERS.filter((p) => p.includeInMultiSearch);
  const settled = await Promise.allSettled(
    activeProviders.map(async (provider) => {
      const result = await withTimeout(
        provider.service.searchAnime(query, provider.domains[0]),
        MULTI_SEARCH_TIMEOUT_MS,
        provider.id
      );
      const results = result?.data?.results || [];
      tagResults(results, provider.label);
      return { provider, results, originalResult: result };
    })
  );

  const allResults = [];
  const errors = [];
  let firstEmptyResult = null;

  for (const entry of settled) {
    if (entry.status === "fulfilled") {
      const { results, originalResult } = entry.value;
      if (results.length > 0) {
        allResults.push(...results);
      } else if (!firstEmptyResult) {
        firstEmptyResult = originalResult;
      }
    } else {
      errors.push(entry.reason);
    }
  }

  if (allResults.length > 0) {
    return {
      success: true,
      source: "Multi",
      data: { results: allResults, count: allResults.length },
    };
  }

  if (firstEmptyResult) {
    return { ...firstEmptyResult, source: "Multi" };
  }

  if (errors[0]) throw errors[0];
  throw new ApiError(502, "No se pudo completar la busqueda en proveedores");
}

async function getAnimeInfo(urlCandidate) {
  const provider = findProviderForUrl(urlCandidate) || PROVIDERS[0];
  const result = await provider.service.getAnimeInfo(urlCandidate);
  if (result && result.data) {
    result.data.slug = urlCandidate;
    result.data.url = urlCandidate;
  }
  return {
    ...result,
    source: result?.source || provider.id,
  };
}

async function getEpisodeLinks(urlCandidate, includeMega, excludeServers) {
  const provider = findProviderForUrl(urlCandidate) || PROVIDERS[0];
  const result = await provider.service.getEpisodeLinks(urlCandidate, includeMega, excludeServers);
  return {
    ...result,
    source: result?.source || provider.id,
  };
}

module.exports = {
  PROVIDERS,
  getCatalog,
  searchAnime,
  getAnimeInfo,
  getEpisodeLinks,
};
