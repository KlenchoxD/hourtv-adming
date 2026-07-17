import { logger } from "../logger.js";
import type { ContentProvider, NormalizedMovie, ProviderResult } from "../types.js";

// Formato esperado del JSON remoto en OWN_CATALOG_URL — ver
// data/provider-config.example.json para un ejemplo completo:
//
// {
//   "entries": [
//     { "tmdbId": 550, "language": "Español", "serverName": "CDN propio",
//       "url": "https://cdn.tuservicio.com/videos/550.m3u8" }
//   ]
// }
interface OwnCatalogEntry {
  tmdbId: number;
  language?: string;
  serverName?: string;
  url: string;
}

interface OwnCatalogFile {
  entries: OwnCatalogEntry[];
}

export class OwnCatalogProvider implements ContentProvider {
  name = "own-catalog";
  private cache: OwnCatalogEntry[] | null = null;

  constructor(private readonly sourceUrl: string) {}

  private async load(): Promise<OwnCatalogEntry[]> {
    if (this.cache) return this.cache;
    if (!this.sourceUrl) {
      this.cache = [];
      return this.cache;
    }
    try {
      const res = await fetch(this.sourceUrl, { signal: AbortSignal.timeout(15000) });
      if (!res.ok) {
        logger.warn("OwnCatalogProvider: no se pudo leer OWN_CATALOG_URL", { status: res.status });
        this.cache = [];
        return this.cache;
      }
      const data = (await res.json()) as OwnCatalogFile;
      this.cache = Array.isArray(data.entries) ? data.entries : [];
    } catch (err) {
      logger.warn("OwnCatalogProvider: error al descargar el catálogo propio", {
        message: (err as Error).message,
      });
      this.cache = [];
    }
    return this.cache;
  }

  async listTmdbIds(): Promise<number[]> {
    const entries = await this.load();
    return Array.from(new Set(entries.map((e) => e.tmdbId).filter((id) => Number.isFinite(id))));
  }

  async findMovieSource(movie: NormalizedMovie): Promise<ProviderResult[]> {
    const entries = await this.load();
    const matches = entries.filter((e) => e.tmdbId === movie.tmdbId && e.url);
    return matches.map((e) => ({
      url: e.url,
      serverName: e.serverName || "Catálogo propio",
      language: e.language || "Español",
      providerId: this.name,
      validatedAt: new Date().toISOString(),
    }));
  }
}
