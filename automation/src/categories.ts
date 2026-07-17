import type { AutomationRules, NormalizedMovie } from "./types.js";

// Mapeo de géneros TMDB (en español, tal como los devuelve la API) a las
// categorías fijas que reconoce el panel/admin y la app.
const GENRE_TO_CATEGORY: Record<string, string> = {
  "Acción": "accion",
  "Terror": "terror",
  "Comedia": "comedia",
  "Romance": "romance",
  "Aventura": "aventura",
  "Drama": "drama",
  "Familiar": "infantil",
  "Animación": "infantil",
  "Suspenso": "terror",
  "Crimen": "drama",
  "Fantasía": "aventura",
  "Ciencia ficción": "aventura",
};

function daysSince(dateStr: string): number {
  const date = new Date(dateStr);
  if (Number.isNaN(date.getTime())) return Number.MAX_SAFE_INTEGER;
  return (Date.now() - date.getTime()) / (24 * 60 * 60 * 1000);
}

export function computeCategories(movie: NormalizedMovie, rules: AutomationRules): string[] {
  const categories = new Set<string>();

  for (const genre of movie.genreNames) {
    const mapped = GENRE_TO_CATEGORY[genre];
    if (mapped) categories.add(mapped);
  }

  if (movie.isAnime) {
    categories.add("anime");
    categories.delete("infantil");
  }

  const ageDays = daysSince(movie.releaseDate);
  const ageYears = ageDays / 365;

  if (ageDays <= rules.recentDaysWindow) {
    categories.add("estrenos");
  }
  if (ageYears > 15) {
    categories.add("antiguas");
  }
  if (movie.popularity >= 40 || movie.voteCount >= 500) {
    categories.add("populares");
  }
  if (movie.rating >= 7 && movie.voteCount >= rules.minVoteCount * 2) {
    categories.add("recomendado");
  }

  if (categories.size === 0) categories.add("drama");

  return Array.from(categories);
}

export function shouldFeature(
  movie: NormalizedMovie,
  categories: string[],
  ageDays: number,
): boolean {
  const veryRecentAndPopular = ageDays <= 30 && movie.popularity >= 60;
  const veryPopularAndRated = movie.popularity >= 120 && movie.rating >= 6.5;
  return veryRecentAndPopular || veryPopularAndRated;
}
