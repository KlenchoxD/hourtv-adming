import {
  CATALOG_PATH,
  CONTENT_PROVIDER_API_KEY,
  CONTENT_PROVIDER_API_URL,
  OWN_CATALOG_URL,
  REPORT_PATH,
  STATE_PATH,
  loadRules,
  loadRunOptions,
} from "./config.js";
import { computeCategories, shouldFeature } from "./categories.js";
import {
  appendMovie,
  currentFeaturedCount,
  enrichMissingFields,
  findExistingMovie,
  readCatalog,
  readJsonSafe,
  writeCatalog,
  writeJson,
} from "./catalog.js";
import { logger } from "./logger.js";
import { HttpProvider } from "./providers/http-provider.js";
import { OwnCatalogProvider } from "./providers/own-catalog-provider.js";
import { discoverRecentMovies, popularMovies, buildNormalizedMovie, summaryFromId } from "./tmdb.js";
import { dedupeByUrl, validateSource } from "./validator.js";
import type {
  AutomationReport,
  AutomationState,
  Catalog,
  CatalogMovie,
  CatalogServer,
  ContentProvider,
  NormalizedMovie,
  SkippedEntry,
  TmdbMovieSummary,
} from "./types.js";

const CONCURRENCY = 4;

async function mapWithConcurrency<T, R>(
  items: T[],
  limit: number,
  fn: (item: T) => Promise<R>,
): Promise<R[]> {
  const results: R[] = new Array(items.length);
  let cursor = 0;
  async function worker() {
    while (cursor < items.length) {
      const idx = cursor++;
      results[idx] = await fn(items[idx]);
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
  return results;
}

function daysSince(dateStr: string): number {
  const date = new Date(dateStr);
  if (Number.isNaN(date.getTime())) return Number.MAX_SAFE_INTEGER;
  return (Date.now() - date.getTime()) / (24 * 60 * 60 * 1000);
}

function isValidDate(dateStr: string): boolean {
  if (!dateStr) return false;
  return !Number.isNaN(new Date(dateStr).getTime());
}

async function main() {
  const startedAt = Date.now();
  const rules = loadRules();
  const runOptions = loadRunOptions();
  const maxAdd = runOptions.maxItems ?? rules.maxAddPerRun;

  logger.info("Iniciando HourTV AutoCatálogo", {
    dryRun: runOptions.dryRun,
    maxAdd,
    forceRefresh: runOptions.forceRefresh,
    rules,
  });

  const report: AutomationReport = {
    generatedAt: new Date().toISOString(),
    durationMs: 0,
    dryRun: runOptions.dryRun,
    moviesFound: 0,
    moviesDiscarded: 0,
    moviesAdded: 0,
    moviesEnriched: 0,
    duplicates: 0,
    tmdbErrors: 0,
    providerErrors: 0,
    invalidSources: 0,
    addedTitles: [],
    skipped: [],
  };

  const tmdbIdsReviewed = new Set<number>();
  const errorsSummary: string[] = [];

  const catalog: Catalog = await readCatalog(CATALOG_PATH);
  const initialMovieCount = catalog.movies.length;

  const providers: ContentProvider[] = [];
  if (OWN_CATALOG_URL) providers.push(new OwnCatalogProvider(OWN_CATALOG_URL));
  if (CONTENT_PROVIDER_API_URL) providers.push(new HttpProvider(CONTENT_PROVIDER_API_URL, CONTENT_PROVIDER_API_KEY));

  if (providers.length === 0) {
    logger.warn(
      "No hay proveedores de reproducción configurados (OWN_CATALOG_URL / CONTENT_PROVIDER_API_URL). " +
        "No se publicará ninguna película nueva hasta configurar al menos uno.",
    );
  }

  // 1. Descubrimiento TMDB: estrenos recientes + populares.
  type CandidateSource = "estrenos" | "populares" | "propio";
  let candidates: { summary: TmdbMovieSummary; source: CandidateSource }[] = [];
  try {
    const [recent, popular] = await Promise.all([
      discoverRecentMovies(rules.recentDaysWindow).catch((err) => {
        errorsSummary.push(`discover/movie: ${(err as Error).message}`);
        report.tmdbErrors++;
        return [] as TmdbMovieSummary[];
      }),
      popularMovies().catch((err) => {
        errorsSummary.push(`movie/popular: ${(err as Error).message}`);
        report.tmdbErrors++;
        return [] as TmdbMovieSummary[];
      }),
    ]);
    candidates = [
      ...recent.map((summary) => ({ summary, source: "estrenos" as const })),
      ...popular.map((summary) => ({ summary, source: "populares" as const })),
    ];
  } catch (err) {
    errorsSummary.push(`Fallo general de descubrimiento TMDB: ${(err as Error).message}`);
    report.tmdbErrors++;
  }

  // Deduplicar candidatos por tmdbId (una película puede salir en ambas listas).
  const byId = new Map<number, { summary: TmdbMovieSummary; source: CandidateSource }>();
  for (const c of candidates) {
    if (!byId.has(c.summary.id)) byId.set(c.summary.id, c);
  }

  // 1b. Candidatos "propios": tmdbId que ya tienen fuente lista en un
  // proveedor (p. ej. lo que ya procesaste con Server Hunter y volcaste en
  // OWN_CATALOG_URL). Estos se publican aunque TMDB no los marque como
  // estreno/popular — es tu propia curación la que manda aquí.
  for (const provider of providers) {
    if (!provider.listTmdbIds) continue;
    try {
      const ids = await provider.listTmdbIds();
      for (const id of ids) {
        if (byId.has(id)) continue;
        try {
          const summary = await summaryFromId(id);
          byId.set(id, { summary, source: "propio" });
        } catch (err) {
          report.tmdbErrors++;
          logger.warn(`No se pudo obtener de TMDB el tmdbId ${id} listado por ${provider.name}`, {
            message: (err as Error).message,
          });
        }
      }
    } catch (err) {
      logger.warn(`Proveedor ${provider.name} falló al listar sus tmdbId`, { message: (err as Error).message });
    }
  }

  candidates = Array.from(byId.values());
  report.moviesFound = candidates.length;
  logger.info(`Candidatos encontrados: ${candidates.length}`);

  function skip(entry: SkippedEntry) {
    report.skipped.push(entry);
    report.moviesDiscarded++;
  }

  // 2. Filtro básico (adulto) antes de pedir detalles a TMDB. Los duplicados
  // se separan aparte: si el enriquecimiento está activado se procesan para
  // completar campos vacíos; si no, simplemente se cuentan y se ignoran.
  const preFiltered: { summary: TmdbMovieSummary; source: CandidateSource }[] = [];
  const duplicateCandidates: { summary: TmdbMovieSummary; source: CandidateSource }[] = [];
  for (const candidate of candidates) {
    const { summary } = candidate;
    tmdbIdsReviewed.add(summary.id);
    if (rules.excludeAdult && summary.adult) {
      skip({ tmdbId: summary.id, title: summary.title, reason: "Contenido adulto excluido por reglas" });
      continue;
    }
    const existing = findExistingMovie(catalog, summary.id, summary.title, (summary.release_date || "").slice(0, 4));
    if (existing) {
      report.duplicates++;
      if (rules.enrichExistingMovies) duplicateCandidates.push(candidate);
      continue;
    }
    preFiltered.push(candidate);
  }

  // 2b. Enriquecimiento opcional (RULE_ENRICH_EXISTING=true): solo completa
  // campos vacíos de películas ya existentes, nunca sobrescribe datos
  // presentes ni toca id/servers/categories/featured.
  let enrichedCount = 0;
  if (rules.enrichExistingMovies && duplicateCandidates.length > 0) {
    const enrichedList = await mapWithConcurrency(duplicateCandidates, CONCURRENCY, async ({ summary, source }) => {
      try {
        return await buildNormalizedMovie(summary, source);
      } catch (err) {
        report.tmdbErrors++;
        logger.warn(`No se pudo enriquecer "${summary.title}"`, { message: (err as Error).message });
        return null;
      }
    });
    for (const fresh of enrichedList) {
      if (!fresh) continue;
      const existing = findExistingMovie(catalog, fresh.tmdbId, fresh.title, fresh.year);
      if (!existing) continue;
      const filled = enrichMissingFields(existing, {
        plot: fresh.plot || undefined,
        cast: fresh.cast || undefined,
        director: fresh.director || undefined,
        writer: fresh.writer || undefined,
        releaseDate: fresh.releaseDate || undefined,
        year: fresh.year || undefined,
        genre: fresh.genre || undefined,
        rating: fresh.rating,
        duration: fresh.duration || undefined,
        poster: fresh.poster || undefined,
        backdrop: fresh.backdrop || undefined,
        tmdbId: fresh.tmdbId,
      });
      if (filled.length > 0) {
        enrichedCount++;
        logger.info(`Enriquecida: "${existing.title}"`, { camposCompletados: filled });
      }
    }
  }
  report.moviesEnriched = enrichedCount;

  const addedSoFar = catalog.movies.length;
  const remainingCapacity = Math.max(0, rules.maxCatalogSize - addedSoFar);
  let added = 0;
  let featuredAddedThisRun = 0;

  // 3. Construir ficha completa (detalles + créditos) con concurrencia limitada.
  const normalizedList = await mapWithConcurrency(preFiltered, CONCURRENCY, async ({ summary, source }) => {
    try {
      return await buildNormalizedMovie(summary, source);
    } catch (err) {
      report.tmdbErrors++;
      skip({ tmdbId: summary.id, title: summary.title, reason: `Error TMDB: ${(err as Error).message}` });
      return null;
    }
  });

  for (const movie of normalizedList) {
    if (!movie) continue;
    if (added >= maxAdd) {
      skip({ tmdbId: movie.tmdbId, title: movie.title, reason: "Límite de incorporaciones por ejecución alcanzado" });
      continue;
    }
    if (added >= remainingCapacity) {
      skip({ tmdbId: movie.tmdbId, title: movie.title, reason: "Catálogo alcanzó el tamaño máximo configurado" });
      continue;
    }

    const rejection = evaluateRules(movie, rules);
    if (rejection) {
      skip({ tmdbId: movie.tmdbId, title: movie.title, reason: rejection });
      continue;
    }

    // 4. Buscar fuentes autorizadas en todos los proveedores configurados.
    let providerResults: import("./types.js").ProviderResult[];
    try {
      const perProvider = await Promise.all(
        providers.map((p) =>
          p.findMovieSource(movie).catch((err) => {
            report.providerErrors++;
            logger.warn(`Proveedor ${p.name} falló para "${movie.title}"`, {
              message: (err as Error).message,
            });
            return [];
          }),
        ),
      );
      providerResults = dedupeByUrl(perProvider.flat());
    } catch (err) {
      report.providerErrors++;
      providerResults = [];
    }

    if (providerResults.length === 0) {
      skip({ tmdbId: movie.tmdbId, title: movie.title, reason: "Sin fuente autorizada configurada" });
      continue;
    }

    // 5. Validar cada fuente antes de publicar.
    const validations = await Promise.all(providerResults.map((r) => validateSource(r)));
    const validServers: CatalogServer[] = [];
    for (const v of validations) {
      if (v.ok) {
        validServers.push({ name: v.result.serverName, url: v.result.url, language: v.result.language });
      } else {
        report.invalidSources++;
        logger.warn(`Fuente descartada para "${movie.title}"`, { reason: v.reason });
      }
    }

    if (validServers.length === 0) {
      skip({ tmdbId: movie.tmdbId, title: movie.title, reason: "Ninguna fuente pasó la validación" });
      continue;
    }

    // 6. Categorías y destacados.
    const categories = computeCategories(movie, rules);
    const ageDays = daysSince(movie.releaseDate);
    let featured = false;
    if (
      featuredAddedThisRun < rules.maxFeaturedNewPerRun &&
      currentFeaturedCount(catalog) < rules.maxFeaturedTotal &&
      shouldFeature(movie, categories, ageDays)
    ) {
      featured = true;
      featuredAddedThisRun++;
    }

    const catalogMovie: CatalogMovie = {
      id: `tmdb-${movie.tmdbId}`,
      title: movie.title,
      plot: movie.plot,
      cast: movie.cast,
      director: movie.director,
      writer: movie.writer,
      releaseDate: movie.releaseDate,
      year: movie.year,
      genre: movie.genre,
      rating: movie.rating,
      duration: movie.duration,
      poster: movie.poster,
      backdrop: movie.backdrop,
      categories,
      featured: featured ? true : undefined,
      servers: validServers,
      tmdbId: movie.tmdbId,
    };

    appendMovie(catalog, catalogMovie);
    report.moviesAdded++;
    report.addedTitles.push(movie.title);
    added++;
    logger.info(`Añadida: "${movie.title}" (${movie.year})`, {
      categorias: categories,
      destacada: featured,
      servidores: validServers.length,
    });
  }

  // 7. Escritura del catálogo (si no es dry-run y hubo cambios).
  const changed = catalog.movies.length !== initialMovieCount || enrichedCount > 0;
  if (!runOptions.dryRun && changed) {
    await writeCatalog(CATALOG_PATH, catalog);
    logger.info(`catalog.json actualizado: ${initialMovieCount} -> ${catalog.movies.length} películas`);
  } else if (runOptions.dryRun) {
    logger.info("Modo dry-run: no se escribió catalog.json", {
      huboCambiosSimulados: changed,
    });
  } else {
    logger.info("Sin cambios: catalog.json no se modificó");
  }

  report.durationMs = Date.now() - startedAt;

  const state: AutomationState = {
    lastRunAt: new Date().toISOString(),
    lastRunStatus: "ok",
    tmdbIdsReviewed: Array.from(tmdbIdsReviewed),
    tmdbIdsPublished: report.addedTitles.length
      ? catalog.movies.slice(-report.moviesAdded).map((m) => Number(m.tmdbId)).filter((n) => !Number.isNaN(n))
      : [],
    totalMoviesInCatalog: catalog.movies.length,
    errorsSummary,
    skipped: report.skipped,
  };

  await writeJson(STATE_PATH, state);
  await writeJson(REPORT_PATH, report);

  logger.info("Ejecución finalizada", {
    encontradas: report.moviesFound,
    añadidas: report.moviesAdded,
    enriquecidas: report.moviesEnriched,
    descartadas: report.moviesDiscarded,
    duplicados: report.duplicates,
    erroresTmdb: report.tmdbErrors,
    erroresProveedor: report.providerErrors,
    fuentesInvalidas: report.invalidSources,
    duracionMs: report.durationMs,
  });
}

function evaluateRules(movie: NormalizedMovie, rules: ReturnType<typeof loadRules>): string | null {
  if (rules.excludeWithoutPoster && !movie.poster) return "Sin póster";
  if (rules.excludeWithoutPlot && !movie.plot) return "Sin sinopsis";
  if (rules.excludeWithoutValidDate && !isValidDate(movie.releaseDate)) return "Sin fecha de estreno válida";

  // Las películas "propio" ya fueron elegidas a mano (vienen de tu scraper),
  // así que no se filtran por popularidad/rating de TMDB — solo por calidad
  // de datos e idioma, igual que las demás.
  if (movie.source !== "propio") {
    if (movie.rating < rules.minRating) return `Rating ${movie.rating} por debajo del mínimo (${rules.minRating})`;
    if (movie.voteCount < rules.minVoteCount) {
      return `Votos ${movie.voteCount} por debajo del mínimo (${rules.minVoteCount})`;
    }
  }

  if (rules.originalLanguage !== "any" && movie.originalLanguage !== rules.originalLanguage) {
    return `Idioma original "${movie.originalLanguage}" no coincide con la regla configurada`;
  }
  return null;
}

main().catch(async (err) => {
  logger.error("Fallo no controlado en la ejecución", { message: (err as Error).message });
  const state: AutomationState = await readJsonSafe<AutomationState>(STATE_PATH, {
    lastRunAt: new Date().toISOString(),
    lastRunStatus: "error",
    tmdbIdsReviewed: [],
    tmdbIdsPublished: [],
    totalMoviesInCatalog: 0,
    errorsSummary: [],
    skipped: [],
  });
  state.lastRunAt = new Date().toISOString();
  state.lastRunStatus = "error";
  state.errorsSummary = [...state.errorsSummary, (err as Error).message];
  await writeJson(STATE_PATH, state).catch(() => {});
  process.exitCode = 1;
});
