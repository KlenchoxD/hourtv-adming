// Serverless adapter for FxxMorgan/anime1v-api (https://github.com/FxxMorgan/anime1v-api, MIT).
// Preserves FxxMorgan author attribution headers and provides optional upstream proxy override
// via ANIME1V_UPSTREAM_URL (+ ANIME1V_UPSTREAM_KEY / ANIME1V_PUBLIC_URL).

const net = require("node:net");
const {
  AUTHOR_HEADER_NAME,
  AUTHOR_HEADER_VALUE,
  ApiError,
  logAttributionOnce,
} = require("../lib/anime1v/utils/api-error");
const defaultAnimeService = require("../lib/anime1v/services/anime.service");
const { resolveEmbedWithMeta } = require("../lib/anime1v/utils/resolvers");

const USER_AGENT =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";

function isPrivateOrLoopbackHost(hostname) {
  const host = String(hostname || "").trim().toLowerCase().replace(/^\[|\]$/g, "");
  if (!host) return true;
  if (host === "localhost" || host.endsWith(".localhost") || host.endsWith(".local") || host.endsWith(".internal")) {
    return true;
  }
  const ipVersion = net.isIP(host);
  if (ipVersion === 4) {
    const parts = host.split(".").map(Number);
    if (parts[0] === 0 || parts[0] === 10 || parts[0] === 127) return true;
    if (parts[0] === 169 && parts[1] === 254) return true;
    if (parts[0] === 172 && parts[1] >= 16 && parts[1] <= 31) return true;
    if (parts[0] === 192 && parts[1] === 168) return true;
    if (parts[0] === 100 && parts[1] >= 64 && parts[1] <= 127) return true;
  }
  if (ipVersion === 6) {
    if (host === "::1" || host === "::" || host.startsWith("fe80:") || host.startsWith("fc") || host.startsWith("fd")) {
      return true;
    }
  }
  return false;
}

function validatePublicHttpUrl(rawUrl) {
  try {
    const parsed = new URL(String(rawUrl || "").trim());
    if (parsed.protocol !== "http:" && parsed.protocol !== "https:") return null;
    if (parsed.username || parsed.password) return null;
    if (isPrivateOrLoopbackHost(parsed.hostname)) return null;
    return parsed;
  } catch {
    return null;
  }
}

function normalizeUpstreamBase(rawUrl) {
  const parsed = validatePublicHttpUrl(rawUrl);
  if (!parsed) return null;
  return parsed.toString().replace(/\/+$/, "");
}

function parseEndpoint(req) {
  const explicit = req?.query?.endpoint;
  if (typeof explicit === "string" && explicit.trim()) {
    return explicit.trim().toLowerCase().replace(/^\/+|\/+$/g, "");
  }
  try {
    const parsed = new URL(req.url || "/", "http://localhost");
    const m = parsed.pathname.match(/\/(?:api\/v1\/anime|api\/anime1v|api\/anime)\/([^/?#]+)/i);
    if (m && m[1]) return m[1].toLowerCase();
  } catch {}
  return "health";
}

function setCorsAndAttribution(res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, x-api-key");
  res.setHeader(AUTHOR_HEADER_NAME, AUTHOR_HEADER_VALUE);
}

function checkApiKey(req, env) {
  const expected = String(env.ANIME1V_API_KEY || "").trim();
  if (!expected) return true;
  const provided =
    (req.headers && (req.headers["x-api-key"] || req.headers["X-Api-Key"])) ||
    (req.query && req.query.apiKey);
  return typeof provided === "string" && provided.trim() === expected;
}

async function forwardToUpstream(upstreamBase, endpoint, req, res, env, fetchImpl) {
  const forwardParams = new URLSearchParams();
  for (const [k, v] of Object.entries(req.query || {})) {
    if (k === "endpoint" || v == null) continue;
    if (Array.isArray(v)) {
      v.forEach((item) => forwardParams.append(k, String(item)));
    } else {
      forwardParams.set(k, String(v));
    }
  }
  const basePath = upstreamBase.endsWith("/api/v1/anime") || upstreamBase.endsWith("/api/anime1v")
    ? upstreamBase
    : `${upstreamBase}/api/v1/anime`;
  const targetUrl = `${basePath}/${endpoint}${forwardParams.toString() ? `?${forwardParams.toString()}` : ""}`;
  const headers = { "User-Agent": USER_AGENT };
  const upstreamKey = String(env.ANIME1V_UPSTREAM_KEY || "").trim();
  if (upstreamKey) headers["x-api-key"] = upstreamKey;

  const upstreamRes = await fetchImpl(targetUrl, {
    headers,
    signal: AbortSignal.timeout(9500),
  });
  const contentType = upstreamRes.headers.get("content-type") || "application/json";
  res.setHeader("Content-Type", contentType);
  if (endpoint === "image-proxy") {
    const buf = Buffer.from(await upstreamRes.arrayBuffer());
    res.setHeader("Cache-Control", "public, max-age=86400");
    return res.status(upstreamRes.status).send(buf);
  }
  const text = await upstreamRes.text();
  try {
    return res.status(upstreamRes.status).json(JSON.parse(text));
  } catch {
    return res.status(upstreamRes.status).send(text);
  }
}

function createHandler({
  env = process.env,
  fetchImpl = fetch,
  animeService = defaultAnimeService,
  resolveEmbed = resolveEmbedWithMeta,
} = {}) {
  logAttributionOnce();

  return async function animeHandler(req, res) {
    setCorsAndAttribution(res);

    if (req.method === "OPTIONS") {
      return res.status(204).end();
    }
    if (req.method !== "GET") {
      return res.status(405).json({ success: false, message: "Método no permitido" });
    }

    const endpoint = parseEndpoint(req);

    if (endpoint === "health") {
      return res.status(200).json({
        success: true,
        status: "ok",
        engine: "vercel-http",
      });
    }

    const upstreamBase = normalizeUpstreamBase(env.ANIME1V_UPSTREAM_URL);
    const publicBaseUrl = normalizeUpstreamBase(env.ANIME1V_PUBLIC_URL);

    if (endpoint === "config") {
      res.setHeader("Cache-Control", "public, max-age=120");
      return res.status(200).json({
        success: true,
        mode: upstreamBase ? "external" : "vercel-http",
        publicBaseUrl: publicBaseUrl || null,
        providers: animeService.PROVIDERS.map((p) => p.id),
      });
    }

    if (upstreamBase) {
      try {
        return await forwardToUpstream(upstreamBase, endpoint, req, res, env, fetchImpl);
      } catch (err) {
        return res.status(502).json({
          success: false,
          message: "No se pudo consultar el servidor externo de anime1v-api",
          details: err?.message,
        });
      }
    }

    if (endpoint === "image-proxy") {
      const target = validatePublicHttpUrl(req.query?.url);
      if (!target) {
        return res.status(400).json({ success: false, message: "Se requiere una url pública http/https válida" });
      }
      try {
        const imgRes = await fetchImpl(target.href, {
          headers: {
            "User-Agent": USER_AGENT,
            Referer: target.origin,
          },
          signal: AbortSignal.timeout(8500),
        });
        if (!imgRes.ok) {
          return res.status(imgRes.status).json({ success: false, message: "Error al descargar la imagen" });
        }
        const buf = Buffer.from(await imgRes.arrayBuffer());
        res.setHeader("Content-Type", imgRes.headers.get("content-type") || "image/jpeg");
        res.setHeader("Cache-Control", "public, max-age=86400");
        return res.status(200).send(buf);
      } catch (err) {
        return res.status(502).json({ success: false, message: "Error al descargar la imagen de portada" });
      }
    }

    if (!checkApiKey(req, env)) {
      return res.status(401).json({ success: false, message: "API Key inválida o faltante" });
    }

    try {
      if (endpoint === "catalog") {
        res.setHeader("Cache-Control", "s-maxage=300, stale-while-revalidate=600");
        const provider = req.query?.provider || req.query?.domain;
        const data = await animeService.getCatalog(req.query?.page, req.query?.genre, provider);
        return res.status(200).json(data);
      }

      if (endpoint === "search") {
        res.setHeader("Cache-Control", "s-maxage=120, stale-while-revalidate=300");
        const q = String(req.query?.q || "").trim();
        if (!q) {
          return res.status(400).json({ success: false, message: "Se requiere el parametro q" });
        }
        const data = await animeService.searchAnime(q, req.query?.domain || req.query?.provider);
        return res.status(200).json(data);
      }

      if (endpoint === "info") {
        res.setHeader("Cache-Control", "s-maxage=300, stale-while-revalidate=600");
        const target = validatePublicHttpUrl(req.query?.url);
        if (!target) {
          return res.status(400).json({ success: false, message: "Se requiere una url pública válida" });
        }
        const data = await animeService.getAnimeInfo(target.href);
        return res.status(200).json(data);
      }

      if (endpoint === "episode") {
        res.setHeader("Cache-Control", "s-maxage=120, stale-while-revalidate=300");
        const target = validatePublicHttpUrl(req.query?.url);
        if (!target) {
          return res.status(400).json({ success: false, message: "Se requiere una url pública válida" });
        }
        const data = await animeService.getEpisodeLinks(
          target.href,
          req.query?.includeMega,
          req.query?.excludeServers
        );
        return res.status(200).json(data);
      }

      if (endpoint === "resolve") {
        res.setHeader("Cache-Control", "no-store");
        let urls = [];
        if (req.query?.urls) {
          try {
            const parsed = JSON.parse(req.query.urls);
            urls = Array.isArray(parsed) ? parsed : [parsed];
          } catch {
            urls = [req.query.urls];
          }
        } else if (req.query?.url) {
          urls = [req.query.url];
        }

        const validUrls = urls.map(validatePublicHttpUrl).filter(Boolean).map((u) => u.href);
        if (validUrls.length === 0) {
          return res.status(400).json({ success: false, message: "Se requiere el parametro url o urls válidos" });
        }

        const attempts = validUrls.map(async (u) => {
          const resolved = await resolveEmbed(u);
          if (resolved && resolved.streamUrl && resolved.streamUrl !== u) {
            return {
              success: true,
              server: resolved.server || "unknown",
              mediaType: resolved.mediaType || (resolved.streamUrl.includes(".m3u8") ? "hls" : "mp4"),
              streamUrl: resolved.streamUrl,
              resolvedFrom: u,
              ...(resolved.headers ? { headers: resolved.headers } : {}),
            };
          }
          throw new Error("No se pudo resolver");
        });

        try {
          const fastest = await Promise.any(attempts);
          return res.status(200).json(fastest);
        } catch {
          return res.status(404).json({
            success: false,
            message: "No se pudo obtener el enlace de streaming directo en ningún servidor",
          });
        }
      }

      return res.status(404).json({ success: false, message: "Endpoint de anime no encontrado" });
    } catch (err) {
      const statusCode = err instanceof ApiError ? err.statusCode : err?.statusCode || 500;
      return res.status(statusCode).json({
        success: false,
        message: err?.message || "Error interno en anime API",
      });
    }
  };
}

const handler = createHandler();
handler.createHandler = createHandler;
handler.validatePublicHttpUrl = validatePublicHttpUrl;

module.exports = handler;
