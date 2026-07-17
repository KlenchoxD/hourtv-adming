import { logger } from "./logger.js";
import type { ProviderResult } from "./types.js";

export type SourceValidation =
  | { ok: true; result: ProviderResult }
  | { ok: false; result: ProviderResult; reason: string };

function isValidUrl(raw: string): URL | null {
  try {
    const url = new URL(raw);
    if (!["http:", "https:"].includes(url.protocol)) return null;
    if (!url.hostname) return null;
    return url;
  } catch {
    return null;
  }
}

// Comprueba una fuente con HEAD (fallback a GET) y timeout corto.
// 200-399 => válida. 403/405 => "requiere verificación especial" (se registra,
// no rompe la ejecución, y la fuente NO se publica). Cualquier otro fallo
// también descarta la fuente sin detener el resto del proceso.
export async function validateSource(result: ProviderResult): Promise<SourceValidation> {
  const url = isValidUrl(result.url);
  if (!url) {
    return { ok: false, result, reason: "URL con formato inválido" };
  }

  const attempt = async (method: "HEAD" | "GET"): Promise<Response> =>
    fetch(url.toString(), { method, signal: AbortSignal.timeout(10000), redirect: "follow" });

  try {
    let res = await attempt("HEAD");
    if (res.status === 405 || res.status === 501) {
      res = await attempt("GET");
    }

    if (res.status >= 200 && res.status < 400) {
      return { ok: true, result };
    }
    if (res.status === 403 || res.status === 405) {
      logger.warn("Fuente requiere verificación especial, se omite por precaución", {
        host: url.hostname,
        status: res.status,
      });
      return { ok: false, result, reason: `Requiere verificación especial (HTTP ${res.status})` };
    }
    return { ok: false, result, reason: `HTTP ${res.status}` };
  } catch (err) {
    return { ok: false, result, reason: `No se pudo validar: ${(err as Error).message}` };
  }
}

export function dedupeByUrl(results: ProviderResult[]): ProviderResult[] {
  const seen = new Set<string>();
  const out: ProviderResult[] = [];
  for (const r of results) {
    if (seen.has(r.url)) continue;
    seen.add(r.url);
    out.push(r);
  }
  return out;
}
