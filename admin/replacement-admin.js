(function (root, factory) {
  const logic = typeof module === 'object' && module.exports
    ? require('./replacement-logic')
    : root.HourTVReplacementLogic;
  const api = factory(logic);
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.HourTVReplacementAdmin = api;
}(typeof globalThis !== 'undefined' ? globalThis : this, function (replacementLogic) {
  'use strict';

  if (!replacementLogic || typeof replacementLogic.buildBatchSummary !== 'function') {
    throw new Error('HourTVReplacementLogic debe cargarse antes de replacement-admin.js');
  }

  function canonicalUrl(value) {
    try {
      const url = new URL(value);
      url.hostname = url.hostname.toLowerCase();
      url.hash = '';
      url.pathname = url.pathname.replace(/\/+$/, '') || '/';
      url.searchParams.sort();
      return url.toString();
    } catch (_) { return null; }
  }

  function sourceMatches(server, locator) {
    return (locator.sourceId && (server.id === locator.sourceId || server.sourceId === locator.sourceId))
      || (locator.previousUrl && canonicalUrl(server.url) === canonicalUrl(locator.previousUrl));
  }

  function locateCatalogSource(catalog, locator) {
    if (!catalog || !locator) return null;
    if (locator.contentType === 'movie') {
      for (let movieIndex = 0; movieIndex < (catalog.movies || []).length; movieIndex += 1) {
        const movie = catalog.movies[movieIndex];
        if (locator.tmdbId != null && String(movie.tmdbId ?? movie.tmdb_id) !== String(locator.tmdbId)) continue;
        const serverIndex = (movie.servers || []).findIndex(server => sourceMatches(server, locator));
        if (serverIndex >= 0) return { container: movie.servers, index: serverIndex, source: movie.servers[serverIndex], item: movie, path: ['movies', movieIndex, 'servers', serverIndex] };
      }
      return null;
    }
    if (locator.contentType === 'episode') {
      for (let seriesIndex = 0; seriesIndex < (catalog.series || []).length; seriesIndex += 1) {
        const series = catalog.series[seriesIndex];
        if (locator.tmdbId != null && String(series.tmdbId ?? series.tmdb_id) !== String(locator.tmdbId)) continue;
        for (let seasonIndex = 0; seasonIndex < (series.seasons || []).length; seasonIndex += 1) {
          const season = series.seasons[seasonIndex];
          if (Number(season.number) !== Number(locator.season)) continue;
          for (let episodeIndex = 0; episodeIndex < (season.episodes || []).length; episodeIndex += 1) {
            const episode = season.episodes[episodeIndex];
            if (Number(episode.number) !== Number(locator.episode)) continue;
            const serverIndex = (episode.servers || []).findIndex(server => sourceMatches(server, locator));
            if (serverIndex >= 0) return { container: episode.servers, index: serverIndex, source: episode.servers[serverIndex], item: series, episode, path: ['series', seriesIndex, 'seasons', seasonIndex, 'episodes', episodeIndex, 'servers', serverIndex] };
          }
        }
      }
    }
    return null;
  }

  function replaceCatalogSource(catalog, candidate) {
    const found = locateCatalogSource(catalog, candidate);
    if (!found) throw new Error('No se encontró exactamente el servidor en la película o episodio indicado');
    const nextUrl = canonicalUrl(candidate.url || candidate.proposedUrl || candidate.proposed_url);
    if (!nextUrl) throw new Error('La URL propuesta no es válida');
    if (found.container.some((server, index) => index !== found.index && canonicalUrl(server.url) === nextUrl)) {
      throw new Error('La URL propuesta ya existe en este contenido');
    }
    const previous = JSON.parse(JSON.stringify(found.source));
    const next = {
      ...found.source,
      name: candidate.proposedName || candidate.proposed_name || found.source.name,
      url: candidate.url || candidate.proposedUrl || candidate.proposed_url,
      replacement: { candidateId: candidate.id || candidate.candidateId || null, previousUrl: found.source.url },
    };
    found.container[found.index] = next;
    return { previous, next, path: found.path, rollback() { found.container[found.index] = previous; } };
  }

  function reorderProviders(providers, providerId, direction) {
    const ordered = providers.slice().sort((a, b) => Number(a.priority) - Number(b.priority));
    const index = ordered.findIndex(provider => provider.id === providerId);
    const destination = Math.max(0, Math.min(ordered.length - 1, index + direction));
    if (index >= 0 && destination !== index) [ordered[index], ordered[destination]] = [ordered[destination], ordered[index]];
    return ordered.map((provider, priority) => ({ ...provider, priority }));
  }

  async function persistProviderOrder(providers, updateProvider) {
    if (typeof updateProvider !== 'function') throw new TypeError('updateProvider es obligatorio');
    const ordered = providers.slice().sort((a, b) => Number(a.priority) - Number(b.priority));
    const offset = ordered.reduce((max, provider) => Math.max(max, Number(provider.priority) || 0), 0) + ordered.length + 1;
    for (let index = 0; index < ordered.length; index += 1) await updateProvider(ordered[index].id, { priority: offset + index });
    for (let index = 0; index < ordered.length; index += 1) await updateProvider(ordered[index].id, { priority: index });
    return ordered.map((provider, priority) => ({ ...provider, priority }));
  }

  function isExpired(candidate, now) {
    const expires = Date.parse(candidate.expiresAt || candidate.expires_at);
    return !Number.isFinite(expires) || expires <= now.getTime();
  }

  function normalizeCandidate(candidate) {
    return {
      ...candidate,
      sourceId: candidate.sourceId || candidate.source_id,
      contentType: candidate.contentType || candidate.content_type,
      type: candidate.type || candidate.contentType || candidate.content_type,
      tmdbId: candidate.tmdbId ?? candidate.tmdb_id,
      season: candidate.season ?? candidate.season_number,
      episode: candidate.episode ?? candidate.episode_number,
      url: candidate.url || candidate.proposedUrl || candidate.proposed_url,
      proposedName: candidate.proposedName || candidate.proposed_name,
      language: candidate.language || candidate.proposed_language_code,
      title: candidate.title || candidate.normalized_title,
      seriesTitle: candidate.seriesTitle || candidate.normalized_title,
      year: candidate.year ?? candidate.release_year,
      checkedAt: candidate.checkedAt || candidate.checked_at,
      expiresAt: candidate.expiresAt || candidate.expires_at,
      reproducible: candidate.reproducible ?? candidate.is_reproducible,
    };
  }

  async function applyReplacement(options) {
    const now = options.now || new Date();
    let candidate = normalizeCandidate(options.candidate);
    if (isExpired(candidate, now)) {
      if (typeof options.revalidate !== 'function') throw new Error('El candidato está vencido y debe validarse otra vez');
      candidate = normalizeCandidate(await options.revalidate(candidate));
    }
    if (candidate.confidence && candidate.confidence !== 'high') throw new Error('Solo se puede aplicar un candidato de confianza alta');
    if (isExpired(candidate, now)) throw new Error('La revalidación no produjo un candidato vigente');
    const change = replaceCatalogSource(options.catalog, candidate);
    try {
      if (options.persist) await options.persist({ candidate, ...change });
      if (options.markPending) await options.markPending({ candidate, ...change });
      return { candidate, ...change };
    } catch (error) {
      change.rollback();
      if (options.onRollback) await options.onRollback({ candidate, error, ...change });
      throw error;
    }
  }

  async function applyReplacementBatch(options) {
    const now = options.now || new Date();
    const candidates = options.candidates.map(normalizeCandidate);
    const summary = replacementLogic.buildBatchSummary(candidates, { now, targetsBySource: options.targetsBySource, maxAgeMs: options.maxAgeMs });
    const snapshot = JSON.parse(JSON.stringify(options.catalog));
    const applied = [];
    try {
      for (const candidate of summary.included) {
        const change = replaceCatalogSource(options.catalog, candidate);
        if (options.persist) await options.persist({ candidate, ...change });
        applied.push({ candidate, ...change });
      }
    } catch (error) {
      Object.keys(options.catalog).forEach(key => delete options.catalog[key]);
      Object.assign(options.catalog, snapshot);
      if (options.rollbackPersisted) await options.rollbackPersisted(applied, error);
      throw error;
    }
    let publishError = null;
    if (applied.length && options.publish) {
      try { await options.publish(); } catch (error) { publishError = error; }
    }
    return { summary, applied, publishError, pendingPublish: Boolean(publishError) };
  }

  return {
    locateCatalogSource,
    replaceCatalogSource,
    reorderProviders,
    persistProviderOrder,
    normalizeCandidate,
    applyReplacement,
    applyReplacementBatch,
  };
}));
