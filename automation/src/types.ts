// Tipos compartidos por todo el automatizador HourTV.

export interface CatalogServer {
  name: string;
  url: string;
  language: string;
}

export interface CatalogMovie {
  id: string;
  title: string;
  plot?: string;
  cast?: string;
  director?: string;
  writer?: string;
  releaseDate?: string;
  year?: string;
  genre?: string;
  rating?: number;
  duration?: string;
  poster?: string;
  backdrop?: string;
  categories?: string[];
  featured?: boolean;
  servers?: CatalogServer[];
  tmdbId?: number;
  seasons?: unknown[];
  [extra: string]: unknown;
}

export interface Catalog {
  version: number;
  movies: CatalogMovie[];
  series: unknown[];
}

// ---- TMDB ----

export interface TmdbMovieSummary {
  id: number;
  title: string;
  original_title: string;
  original_language: string;
  overview: string;
  popularity: number;
  vote_average: number;
  vote_count: number;
  release_date: string;
  adult: boolean;
  poster_path: string | null;
  backdrop_path: string | null;
  genre_ids: number[];
}

export interface TmdbCrewMember {
  name: string;
  job: string;
  department: string;
}

export interface TmdbCastMember {
  name: string;
  order: number;
}

export interface TmdbCredits {
  cast: TmdbCastMember[];
  crew: TmdbCrewMember[];
}

export interface TmdbMovieDetails {
  id: number;
  title: string;
  original_title: string;
  original_language: string;
  overview: string;
  popularity: number;
  vote_average: number;
  vote_count: number;
  release_date: string;
  runtime: number | null;
  adult: boolean;
  poster_path: string | null;
  backdrop_path: string | null;
  genres: { id: number; name: string }[];
}

// ---- Normalización ----

export interface NormalizedMovie {
  tmdbId: number;
  title: string;
  originalTitle: string;
  originalLanguage: string;
  plot: string;
  cast: string;
  director: string;
  writer: string;
  releaseDate: string;
  year: string;
  genre: string;
  genreNames: string[];
  rating: number;
  voteCount: number;
  popularity: number;
  duration: string;
  poster: string;
  backdrop: string;
  isAnime: boolean;
  source: "estrenos" | "populares" | "propio";
}

// ---- Proveedores de reproducción ----

export interface ProviderResult {
  url: string;
  serverName: string;
  language: string;
  providerId?: string;
  validatedAt: string;
}

export interface ContentProvider {
  name: string;
  findMovieSource(movie: NormalizedMovie): Promise<ProviderResult[]>;
  // Opcional: proveedores que pueden enumerar TODOS los tmdbId que ya tienen
  // listos (p. ej. OwnCatalogProvider a partir de un scraper propio) hacen
  // que el bot los tome como candidatos a publicar directamente, sin
  // depender de que TMDB los marque como estreno/popular.
  listTmdbIds?(): Promise<number[]>;
}

// ---- Reglas / configuración ----

export interface AutomationRules {
  originalLanguage: "es" | "en" | "any";
  excludeAdult: boolean;
  excludeWithoutPoster: boolean;
  excludeWithoutPlot: boolean;
  excludeWithoutValidDate: boolean;
  minRating: number;
  minVoteCount: number;
  recentDaysWindow: number;
  maxAddPerRun: number;
  maxCatalogSize: number;
  maxFeaturedNewPerRun: number;
  maxFeaturedTotal: number;
  enrichExistingMovies: boolean;
}

export interface RunOptions {
  dryRun: boolean;
  maxItems?: number;
  forceRefresh: boolean;
}

// ---- Reportes ----

export interface SkippedEntry {
  tmdbId: number;
  title: string;
  reason: string;
}

export interface AutomationReport {
  generatedAt: string;
  durationMs: number;
  dryRun: boolean;
  moviesFound: number;
  moviesDiscarded: number;
  moviesAdded: number;
  moviesEnriched: number;
  duplicates: number;
  tmdbErrors: number;
  providerErrors: number;
  invalidSources: number;
  addedTitles: string[];
  skipped: SkippedEntry[];
}

export interface AutomationState {
  lastRunAt: string;
  lastRunStatus: "ok" | "error";
  tmdbIdsReviewed: number[];
  tmdbIdsPublished: number[];
  totalMoviesInCatalog: number;
  errorsSummary: string[];
  skipped: SkippedEntry[];
}
