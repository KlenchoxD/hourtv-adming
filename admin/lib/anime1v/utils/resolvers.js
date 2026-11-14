// Adapted from FxxMorgan/anime1v-api (MIT) for HTTP/Vercel runtime.
// Retains pure-HTTP extractors and adds HTTP extractors for Zilla Networks, YourUpload & MP4Upload.

const axios = require("axios");
const { URL } = require("node:url");
const {
  fetchHtmlWithHeaders,
  findFirstUrl,
  isLikelyVideoUrl,
  normalizeExtractedUrl,
} = require("./http");
const { extractVoe } = require("./resolvers/voe.resolver");
const { extractStreamwish } = require("./resolvers/streamwish.resolver");
const { extractStreamtape } = require("./resolvers/streamtape.resolver");

function getRefererForUrl(url) {
  try {
    return `${new URL(url).origin}/`;
  } catch (_error) {
    return "https://animeav1.com/";
  }
}

function classifyMediaType(url) {
  const lower = String(url || "").toLowerCase();
  if (lower.includes(".m3u8") || lower.includes("/m3u8/")) return "hls";
  return "mp4";
}

function withMeta(streamUrl, server, headers, mediaType) {
  if (!streamUrl) return null;
  const result = {
    server,
    mediaType: mediaType || classifyMediaType(streamUrl),
    streamUrl,
  };
  if (headers && Object.keys(headers).length > 0) {
    result.headers = headers;
  }
  return result;
}

async function resolveZillaNetworks(url) {
  const match = /\/play\/([a-zA-Z0-9_-]{8,64})/i.exec(url) || /\/m3u8\/([a-zA-Z0-9_-]{8,64})/i.exec(url);
  if (!match || !match[1]) return null;
  const origin = new URL(url).origin;
  const m3u8Url = `${origin}/m3u8/${match[1]}`;
  try {
    const res = await axios.get(m3u8Url, {
      timeout: 6000,
      headers: {
        "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
        Referer: `${origin}/`,
      },
      validateStatus: (status) => status >= 200 && status < 400,
    });
    if (typeof res.data === "string" && res.data.includes("#EXTM3U")) {
      return withMeta(m3u8Url, "zilla", { Referer: `${origin}/` }, "hls");
    }
  } catch (_err) {
    return null;
  }
  return null;
}

async function resolveYourUploadUrl(url, referer) {
  try {
    const { html } = await fetchHtmlWithHeaders(url, referer || "https://animeav1.com/");
    const extracted = findFirstUrl(html, [
      /file\s*:\s*['"](https?:\/\/[^'"]+\.(?:mp4|m3u8)[^'"]*)['"]/i,
      /file\s*:\s*['"](https?:\/\/[^'"]*vidcache[^'"]*)['"]/i,
    ]);
    if (extracted && !extracted.includes("/images/")) {
      return withMeta(extracted, "yourupload", { Referer: "https://www.yourupload.com/" });
    }
  } catch (_err) {}
  return null;
}

async function resolveMp4UploadUrl(url, referer) {
  try {
    let target = url;
    const parsed = new URL(url);
    const pathname = parsed.pathname.toLowerCase();
    if (!pathname.includes("embed") && !pathname.endsWith(".html")) {
      const slug = pathname.split("/").filter(Boolean).pop();
      if (slug) target = `https://www.mp4upload.com/embed-${slug}.html`;
    }
    const { html } = await fetchHtmlWithHeaders(target, referer || "https://animeav1.com/");
    const extracted = findFirstUrl(html, [
      /src\s*:\s*["'](https?:\/\/[^"']+\.mp4[^"']*)["']/i,
      /(https?:\/\/[^\s"'<>]+\/d\/[^\s"'<>]+\/video\.mp4[^\s"'<>]*)/i,
      /(https?:\/\/[^\s"'<>]+\.mp4[^\s"'<>]*)/i,
    ]);
    if (extracted) {
      return withMeta(extracted, "mp4upload", { Referer: "https://www.mp4upload.com/" });
    }
  } catch (_err) {}
  return null;
}

async function resolveVidhideUrl(url, referer) {
  try {
    const { html } = await fetchHtmlWithHeaders(url, referer);
    return findFirstUrl(html, [
      /sources?\s*:\s*\[\s*\{[^}]*(?:file|src)\s*:\s*["'](https?:\/\/[^"']+)["']/i,
      /"file"\s*:\s*"([^"]+)"/i,
      /"source"\s*:\s*"([^"]+)"/i,
      /file\s*:\s*'([^']+)'/i,
    ]);
  } catch (_err) {
    return null;
  }
}

async function resolveHqqUrl(url, referer) {
  try {
    const { html } = await fetchHtmlWithHeaders(url, referer);
    return findFirstUrl(html, [
      /sources?\s*:\s*\[\s*\{[^}]*file\s*:\s*["'](https?:\/\/[^"']+)["']/i,
      /file\s*:\s*"([^"]+\.mp4[^"]*)"/i,
      /video(?:\d+)?\s*=\s*["']([^"']+\.mp4[^"']+)["']/i,
    ]);
  } catch (_err) {
    return null;
  }
}

async function resolveMixdropUrl(url, referer) {
  try {
    const { html } = await fetchHtmlWithHeaders(url, referer);
    const patterns = [
      /MDCore\.wurl\s*=\s*"([^"]+)"/i,
      /MDCore\.vsrc\s*=\s*"([^"]+)"/i,
      /MDCore\.source\s*=\s*"([^"]+)"/i,
      /\|MDCore\|[^|]*\|wurl\|[^|]*\|(https?[^|]+)/i,
      /(https?:\/\/[a-z0-9]+\.mixdrop\.[a-z]+\/[^\s"'<>]+\.mp4[^\s"'<>]*)/i,
      /(https?:\/\/[a-z0-9]+\.mxdcontent\.[a-z]+\/[^\s"'<>]+\.mp4[^\s"'<>]*)/i,
      /"(https?:\/\/[^"]+\.mp4[^"]*)"/i,
      /\/\/(s-delivery\d+[^\s"']+\.mp4[^\s"']*)/i,
    ];
    for (const pattern of patterns) {
      const match = html.match(pattern);
      if (match && match[1]) {
        const candidate = match[1].startsWith("//") ? `https:${match[1]}` : match[1];
        if (isLikelyVideoUrl(candidate)) return normalizeExtractedUrl(candidate);
      }
    }
  } catch (_err) {}
  return null;
}

async function resolveDoodstreamUrl(url, referer) {
  try {
    const embedUrl = url.replace(/\/d\//, "/e/");
    const { html } = await fetchHtmlWithHeaders(embedUrl, referer);
    const passMatch = html.match(/\/pass_md5\/[^'"\s]+/i);
    if (passMatch) {
      const passUrl = `https://${new URL(embedUrl).hostname}${passMatch[0]}`;
      const tokenResponse = await fetchHtmlWithHeaders(passUrl, embedUrl);
      const tokenUrl = String(tokenResponse.html || "").trim();
      if (tokenUrl.startsWith("http") || tokenUrl.startsWith("//")) {
        const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
        let randomStr = "";
        for (let i = 0; i < 10; i++) randomStr += chars.charAt(Math.floor(Math.random() * chars.length));
        return `${tokenUrl}${randomStr}?token=${passMatch[0].split("/").pop()}&expiry=${Date.now()}`;
      }
    }
    return findFirstUrl(html, [
      /(https?:\/\/[^\s"'<>]+\.mp4[^\s"'<>]*)/i,
      /(https?:\/\/[^\s"'<>]+\.m3u8[^\s"'<>]*)/i,
      /"file"\s*:\s*"([^"]+)"/i,
      /source\s*src\s*=\s*["']([^"']+)["']/i,
    ]);
  } catch (_err) {
    return null;
  }
}

async function resolveDroploadUrl(url, referer) {
  try {
    const { html } = await fetchHtmlWithHeaders(url, referer);
    const extracted = findFirstUrl(html, [
      /(https?:\/\/[^\s"'<>]+\.m3u8[^\s"'<>]*)/i,
      /sources?\s*:\s*\[\s*\{[^}]*(?:file|src)\s*:\s*["'](https?:\/\/[^"']+)["']/i,
      /file\s*:\s*["'](https?:[^\s"']+)["']/i,
      /"file"\s*:\s*"([^"]+)"/i,
      /"source"\s*:\s*"([^"]+)"/i,
      /(https?:\/\/[^\s"'<>]+\.mp4[^\s"'<>]*)/i,
    ]);
    if (extracted && !extracted.startsWith("blob:")) return extracted;
    const dataMatch = html.match(/data-src=["']([^"']+\.(?:m3u8|mp4)[^"']*)["']/i);
    if (dataMatch && dataMatch[1] && !dataMatch[1].startsWith("blob:")) {
      return normalizeExtractedUrl(dataMatch[1]);
    }
  } catch (_err) {}
  return null;
}

async function resolveEmbedWithMeta(url, parentUrl = null) {
  if (!url) return null;
  let parsed;
  try {
    parsed = new URL(url);
  } catch (_error) {
    return null;
  }

  const host = parsed.hostname.replace(/^www\./, "").toLowerCase();
  const pathname = parsed.pathname.toLowerCase();
  const referer = getRefererForUrl(parentUrl || url);
  const selfOrigin = `${parsed.origin}/`;

  if (/zilla-networks\.com$/i.test(host)) {
    const zilla = await resolveZillaNetworks(url);
    if (zilla) return zilla;
  }
  if (/yourupload\.com$/i.test(host)) {
    const yu = await resolveYourUploadUrl(url, referer);
    if (yu) return yu;
  }
  if (/mp4upload\.com$/i.test(host)) {
    const mp4 = await resolveMp4UploadUrl(url, referer);
    if (mp4) return mp4;
  }
  if (/wish|awish|playnix|medix|niramirus|kravaxxa|davioad|haxlopp|tryzendm|dumbalag|dhcplay|hglink/i.test(host)) {
    const resolved = await extractStreamwish(url);
    if (resolved) return withMeta(resolved, "streamwish", { Referer: selfOrigin });
  }
  if (/streamtape/i.test(host)) {
    const resolved = await extractStreamtape(url);
    if (resolved) return withMeta(resolved, "streamtape", { Referer: selfOrigin });
  }
  if (/voe/i.test(host) || /\/e\//.test(pathname)) {
    const resolved = await extractVoe(url);
    if (resolved) return withMeta(resolved, "voe");
  }
  if (/hqq\.tv|netu|waaw/i.test(host)) {
    const resolved = await resolveHqqUrl(url, referer);
    if (resolved) return withMeta(resolved, "hqq", { Referer: selfOrigin });
  }
  if (/vidhide/i.test(host)) {
    const resolved = await resolveVidhideUrl(url, referer);
    if (resolved) return withMeta(resolved, "vidhide", { Referer: selfOrigin });
  }
  if (/mixdrop|mxdcontent/i.test(host)) {
    const resolved = await resolveMixdropUrl(url, referer);
    if (resolved) return withMeta(resolved, "mixdrop", { Referer: selfOrigin });
  }
  if (/dood|dstream|ds2play|doods/i.test(host)) {
    const resolved = await resolveDoodstreamUrl(url, referer);
    if (resolved) return withMeta(resolved, "doodstream", { Referer: selfOrigin });
  }
  if (/dropload|dr0pstream|drop\.download/i.test(host)) {
    const resolved = await resolveDroploadUrl(url, referer);
    if (resolved) return withMeta(resolved, "dropload", { Referer: selfOrigin });
  }

  return null;
}

async function resolveEmbedUrl(url, parentUrl = null) {
  const result = await resolveEmbedWithMeta(url, parentUrl);
  return result ? result.streamUrl : url;
}

module.exports = {
  resolveEmbedWithMeta,
  resolveEmbedUrl,
  resolveStreamwishUrl: extractStreamwish,
  resolveStreamtapeUrl: extractStreamtape,
  resolveVoeUrl: extractVoe,
  resolveVidhideUrl,
  resolveHqqUrl,
  resolveMixdropUrl,
  resolveDoodstreamUrl,
  resolveDroploadUrl,
};
