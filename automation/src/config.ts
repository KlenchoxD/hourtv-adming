import type { AutomationRules, RunOptions } from "./types.js";

function envBool(name: string, fallback: boolean): boolean {
  const raw = process.env[name];
  if (raw === undefined || raw === "") return fallback;
  return raw.toLowerCase() === "true" || raw === "1";
}

function envNumber(name: string, fallback: number): number {
  const raw = process.env[name];
  if (raw === undefined || raw === "") return fallback;
  const n = Number(raw);
  return Number.isFinite(n) ? n : fallback;
}

function envEnum<T extends string>(name: string, allowed: readonly T[], fallback: T): T {
  const raw = (process.env[name] || "").toLowerCase();
  return (allowed as readonly string[]).includes(raw) ? (raw as T) : fallback;
}

export function loadRules(): AutomationRules {
  return {
    originalLanguage: envEnum("RULE_ORIGINAL_LANGUAGE", ["es", "en", "any"] as const, "any"),
    excludeAdult: envBool("RULE_EXCLUDE_ADULT", true),
    excludeWithoutPoster: envBool("RULE_EXCLUDE_NO_POSTER", true),
    excludeWithoutPlot: envBool("RULE_EXCLUDE_NO_PLOT", true),
    excludeWithoutValidDate: envBool("RULE_EXCLUDE_NO_DATE", true),
    minRating: envNumber("RULE_MIN_RATING", 5.5),
    minVoteCount: envNumber("RULE_MIN_VOTES", 50),
    recentDaysWindow: envNumber("RULE_RECENT_DAYS", 120),
    maxAddPerRun: envNumber("RULE_MAX_ADD_PER_RUN", 10),
    maxCatalogSize: envNumber("RULE_MAX_CATALOG_SIZE", 2000),
    maxFeaturedNewPerRun: envNumber("RULE_MAX_FEATURED_NEW_PER_RUN", 2),
    maxFeaturedTotal: envNumber("RULE_MAX_FEATURED_TOTAL", 8),
    enrichExistingMovies: envBool("RULE_ENRICH_EXISTING", false),
  };
}

export function loadRunOptions(): RunOptions {
  return {
    dryRun: envBool("DRY_RUN", false),
    maxItems: process.env.MAX_ITEMS ? envNumber("MAX_ITEMS", 10) : undefined,
    forceRefresh: envBool("FORCE_REFRESH", false),
  };
}

export const TMDB_API_KEY = process.env.TMDB_API_KEY || "";
export const TMDB_LANGUAGE = process.env.TMDB_LANGUAGE || "es-ES";
export const TMDB_REGION = process.env.TMDB_REGION || "CO";
export const TMDB_BASE_URL = "https://api.themoviedb.org/3";
export const TMDB_IMAGE_BASE = "https://image.tmdb.org/t/p";

export const OWN_CATALOG_URL = process.env.OWN_CATALOG_URL || "";
export const CONTENT_PROVIDER_API_URL = process.env.CONTENT_PROVIDER_API_URL || "";
export const CONTENT_PROVIDER_API_KEY = process.env.CONTENT_PROVIDER_API_KEY || "";

export const CATALOG_PATH = process.env.CATALOG_PATH || "catalog.json";
export const STATE_PATH = process.env.STATE_PATH || "data/automation-state.json";
export const REPORT_PATH = process.env.REPORT_PATH || "data/automation-report.json";

export const ALLOWED_CATEGORIES = [
  "recomendado",
  "estrenos",
  "populares",
  "antiguas",
  "terror",
  "accion",
  "comedia",
  "romance",
  "aventura",
  "drama",
  "infantil",
  "anime",
] as const;
