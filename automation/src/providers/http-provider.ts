import { logger } from "../logger.js";
import type { ContentProvider, NormalizedMovie, ProviderResult } from "../types.js";

// Contrato esperado de la API configurada en CONTENT_PROVIDER_API_URL.
//
// Petición:  GET {CONTENT_PROVIDER_API_URL}?tmdbId=550&title=Fight%20Club&year=1999
//            Header: Authorization: Bearer {CONTENT_PROVIDER_API_KEY}
//
// Respuesta 200 esperada:
// {
//   "sources": [
//     { "url": "https://...", "serverName": "Servidor 1", "language": "Español" }
//   ]
// }
// Respuesta 404 = sin fuente disponible (no es un error).
interface HttpProviderSource {
  url: string;
  serverName?: string;
  language?: string;
}

interface HttpProviderResponse {
  sources?: HttpProviderSource[];
}

export class HttpProvider implements ContentProvider {
  name = "http-provider";

  constructor(
    private readonly apiUrl: string,
    private readonly apiKey: string,
  ) {}

  async findMovieSource(movie: NormalizedMovie): Promise<ProviderResult[]> {
    if (!this.apiUrl) return [];
    try {
      const url = new URL(this.apiUrl);
      url.searchParams.set("tmdbId", String(movie.tmdbId));
      url.searchParams.set("title", movie.title);
      if (movie.year) url.searchParams.set("year", movie.year);

      const res = await fetch(url.toString(), {
        headers: this.apiKey ? { Authorization: `Bearer ${this.apiKey}` } : undefined,
        signal: AbortSignal.timeout(15000),
      });

      if (res.status === 404) return [];
      if (res.status === 429) {
        logger.warn("HttpProvider: rate limit del proveedor externo", { tmdbId: movie.tmdbId });
        return [];
      }
      if (!res.ok) {
        logger.warn("HttpProvider: respuesta no exitosa", { status: res.status, tmdbId: movie.tmdbId });
        return [];
      }

      const data = (await res.json()) as HttpProviderResponse;
      const sources = Array.isArray(data.sources) ? data.sources : [];
      return sources
        .filter((s) => s.url)
        .map((s) => ({
          url: s.url,
          serverName: s.serverName || "Servidor",
          language: s.language || "Español",
          providerId: this.name,
          validatedAt: new Date().toISOString(),
        }));
    } catch (err) {
      logger.warn("HttpProvider: fallo al consultar el proveedor", {
        message: (err as Error).message,
        tmdbId: movie.tmdbId,
      });
      return [];
    }
  }
}
