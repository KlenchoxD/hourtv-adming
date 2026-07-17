import { promises as fs } from "node:fs";
import path from "node:path";
import { logger } from "./logger.js";
import type { Catalog, CatalogMovie } from "./types.js";

export function normalizeTitle(title: string): string {
  return title
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

export async function readCatalog(catalogPath: string): Promise<Catalog> {
  try {
    const raw = await fs.readFile(catalogPath, "utf-8");
    const parsed = JSON.parse(raw) as Partial<Catalog>;
    return {
      version: parsed.version ?? 2,
      movies: Array.isArray(parsed.movies) ? parsed.movies : [],
      series: Array.isArray(parsed.series) ? parsed.series : [],
    };
  } catch (err) {
    logger.warn("No se pudo leer catalog.json existente, se usará uno vacío", {
      message: (err as Error).message,
    });
    return { version: 2, movies: [], series: [] };
  }
}

export async function writeCatalog(catalogPath: string, catalog: Catalog): Promise<void> {
  const ordered: Catalog = {
    version: 2,
    movies: catalog.movies,
    series: catalog.series,
  };
  const json = JSON.stringify(ordered, null, 2) + "\n";
  // Verificación de integridad antes de escribir: debe volver a parsear igual.
  JSON.parse(json);
  await fs.mkdir(path.dirname(path.resolve(catalogPath)), { recursive: true });
  await fs.writeFile(catalogPath, json, "utf-8");
}

// Busca una película ya existente en el catálogo que corresponda al mismo
// título TMDB: por tmdbId si ya lo tiene, o por título normalizado + año como
// respaldo seguro para entradas antiguas creadas a mano.
export function findExistingMovie(
  catalog: Catalog,
  tmdbId: number,
  title: string,
  year: string,
): CatalogMovie | undefined {
  const normalized = normalizeTitle(title);
  return catalog.movies.find((m) => {
    if (typeof m.tmdbId === "number") return m.tmdbId === tmdbId;
    return normalizeTitle(String(m.title || "")) === normalized && String(m.year || "") === year;
  });
}

export function isDuplicate(catalog: Catalog, tmdbId: number, title: string, year: string): boolean {
  return findExistingMovie(catalog, tmdbId, title, year) !== undefined;
}

// Rellena únicamente los campos vacíos/ausentes de una película ya existente,
// sin tocar id, servers, categories, featured ni ningún dato ya presente
// (incluye ediciones manuales hechas desde admin/index.html).
export function enrichMissingFields(existing: CatalogMovie, fresh: Partial<CatalogMovie>): string[] {
  const filledFields: string[] = [];
  const fillable: (keyof CatalogMovie & string)[] = [
    "plot",
    "cast",
    "director",
    "writer",
    "releaseDate",
    "year",
    "genre",
    "rating",
    "duration",
    "poster",
    "backdrop",
  ];
  for (const field of fillable) {
    const current = existing[field];
    const isEmpty = current === undefined || current === null || current === "";
    const value = fresh[field];
    if (isEmpty && value !== undefined && value !== null && value !== "") {
      existing[field] = value as never;
      filledFields.push(field);
    }
  }
  if (existing.tmdbId === undefined && typeof fresh.tmdbId === "number") {
    existing.tmdbId = fresh.tmdbId;
    filledFields.push("tmdbId");
  }
  return filledFields;
}

export function currentFeaturedCount(catalog: Catalog): number {
  return catalog.movies.filter((m) => m.featured === true).length;
}

export async function readJsonSafe<T>(filePath: string, fallback: T): Promise<T> {
  try {
    const raw = await fs.readFile(filePath, "utf-8");
    return JSON.parse(raw) as T;
  } catch {
    return fallback;
  }
}

export async function writeJson(filePath: string, data: unknown): Promise<void> {
  await fs.mkdir(path.dirname(path.resolve(filePath)), { recursive: true });
  await fs.writeFile(filePath, JSON.stringify(data, null, 2) + "\n", "utf-8");
}

export function appendMovie(catalog: Catalog, movie: CatalogMovie): void {
  catalog.movies.push(movie);
}
