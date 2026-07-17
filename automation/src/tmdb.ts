import {
  TMDB_API_KEY,
  TMDB_BASE_URL,
  TMDB_IMAGE_BASE,
  TMDB_LANGUAGE,
  TMDB_REGION,
} from "./config.js";
import { logger } from "./logger.js";
import type {
  NormalizedMovie,
  TmdbCredits,
  TmdbMovieDetails,
  TmdbMovieSummary,
} from "./types.js";

const GENRE_MAP: Record<number, string> = {
  28: "Acción",
  12: "Aventura",
  16: "Animación",
  35: "Comedia",
  80: "Crimen",
  99: "Documental",
  18: "Drama",
  10751: "Familiar",
  14: "Fantasía",
  36: "Historia",
  27: "Terror",
  10402: "Música",
  9648: "Misterio",
  10749: "Romance",
  878: "Ciencia ficción",
  10770: "Película de TV",
  53: "Suspenso",
  10752: "Bélica",
  37: "Western",
};

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function tmdbFetch<T>(path: string, params: Record<string, string> = {}, attempt = 1): Promise<T> {
  if (!TMDB_API_KEY) {
    throw new Error("Falta la variable TMDB_API_KEY");
  }
  const url = new URL(`${TMDB_BASE_URL}${path}`);
  url.searchParams.set("api_key", TMDB_API_KEY);
  url.searchParams.set("language", TMDB_LANGUAGE);
  for (const [k, v] of Object.entries(params)) url.searchParams.set(k, v);

  const res = await fetch(url.toString());

  if (res.status === 429 && attempt <= 4) {
    const retryAfter = Number(res.headers.get("retry-after") || "1");
    logger.warn("TMDB rate limit, reintentando", { path, attempt, retryAfter });
    await sleep(Math.max(retryAfter, 1) * 1000);
    return tmdbFetch<T>(path, params, attempt + 1);
  }

  if (!res.ok) {
    throw new Error(`TMDB ${path} respondió ${res.status}`);
  }
  return (await res.json()) as T;
}

export async function discoverRecentMovies(daysWindow: number, page = 1): Promise<TmdbMovieSummary[]> {
  const to = new Date();
  const from = new Date(to.getTime() - daysWindow * 24 * 60 * 60 * 1000);
  const fmt = (d: Date) => d.toISOString().slice(0, 10);
  const data = await tmdbFetch<{ results: TmdbMovieSummary[] }>("/discover/movie", {
    region: TMDB_REGION,
    sort_by: "popularity.desc",
    "release_date.gte": fmt(from),
    "release_date.lte": fmt(to),
    include_adult: "false",
    page: String(page),
  });
  return data.results || [];
}

export async function popularMovies(page = 1): Promise<TmdbMovieSummary[]> {
  const data = await tmdbFetch<{ results: TmdbMovieSummary[] }>("/movie/popular", {
    region: TMDB_REGION,
    page: String(page),
  });
  return data.results || [];
}

// Construye un "summary" equivalente al de discover/popular a partir de un
// tmdbId suelto (para candidatos que vienen de un proveedor propio, no de
// las listas de estrenos/populares de TMDB).
export async function summaryFromId(id: number): Promise<TmdbMovieSummary> {
  const details = await movieDetails(id);
  return {
    id: details.id,
    title: details.title,
    original_title: details.original_title,
    original_language: details.original_language,
    overview: details.overview,
    popularity: details.popularity,
    vote_average: details.vote_average,
    vote_count: details.vote_count,
    release_date: details.release_date,
    adult: details.adult,
    poster_path: details.poster_path,
    backdrop_path: details.backdrop_path,
    genre_ids: (details.genres || []).map((g) => g.id),
  };
}

export async function movieDetails(id: number): Promise<TmdbMovieDetails> {
  return tmdbFetch<TmdbMovieDetails>(`/movie/${id}`);
}

export async function movieCredits(id: number): Promise<TmdbCredits> {
  return tmdbFetch<TmdbCredits>(`/movie/${id}/credits`);
}

// Overview en el idioma original como respaldo si el español viene vacío.
export async function movieOverviewFallback(id: number, originalLanguage: string): Promise<string> {
  try {
    const data = await tmdbFetch<{ overview: string }>(`/movie/${id}`, {
      language: originalLanguage || "en-US",
    });
    return data.overview || "";
  } catch {
    return "";
  }
}

function posterUrl(path: string | null): string {
  return path ? `${TMDB_IMAGE_BASE}/w780${path}` : "";
}

function backdropUrl(path: string | null): string {
  return path ? `${TMDB_IMAGE_BASE}/w1280${path}` : "";
}

function isLikelyAnime(genreNames: string[], originalLanguage: string): boolean {
  return genreNames.includes("Animación") && originalLanguage === "ja";
}

export function mapGenreNames(genreIds: number[]): string[] {
  return genreIds.map((id) => GENRE_MAP[id]).filter((n): n is string => Boolean(n));
}

export async function buildNormalizedMovie(
  summary: TmdbMovieSummary,
  source: "estrenos" | "populares" | "propio",
): Promise<NormalizedMovie> {
  const details = await movieDetails(summary.id);
  const credits = await movieCredits(summary.id);

  let plot = details.overview?.trim() || "";
  if (!plot) {
    plot = await movieOverviewFallback(details.id, details.original_language);
  }

  const cast = credits.cast
    .slice()
    .sort((a, b) => a.order - b.order)
    .slice(0, 10)
    .map((c) => c.name)
    .join(", ");

  const director = Array.from(
    new Set(credits.crew.filter((c) => c.job === "Director").map((c) => c.name)),
  ).join(", ");

  const writer = Array.from(
    new Set(
      credits.crew
        .filter((c) => ["Writer", "Screenplay", "Story"].includes(c.job))
        .map((c) => c.name),
    ),
  ).join(", ");

  const genreNames = details.genres?.length
    ? details.genres.map((g) => g.name)
    : mapGenreNames(summary.genre_ids || []);

  const releaseDate = details.release_date || summary.release_date || "";
  const year = releaseDate ? releaseDate.slice(0, 4) : "";

  return {
    tmdbId: details.id,
    title: details.title?.trim() || details.original_title,
    originalTitle: details.original_title,
    originalLanguage: details.original_language,
    plot,
    cast,
    director,
    writer,
    releaseDate,
    year,
    genre: genreNames.join(", "),
    genreNames,
    rating: Math.round((details.vote_average ?? 0) * 10) / 10,
    voteCount: details.vote_count ?? 0,
    popularity: details.popularity ?? 0,
    duration: details.runtime ? `${details.runtime} min` : "",
    poster: posterUrl(details.poster_path),
    backdrop: backdropUrl(details.backdrop_path),
    isAnime: isLikelyAnime(genreNames, details.original_language),
    source,
  };
}
