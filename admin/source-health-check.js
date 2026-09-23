#!/usr/bin/env node
const fs = require('node:fs');
const crypto = require('node:crypto');

const MEDIA_TYPES = new Set(['video/mp4', 'video/x-matroska', 'video/webm', 'video/mp2t', 'application/octet-stream']);
const HLS_TYPES = new Set(['application/vnd.apple.mpegurl', 'application/x-mpegurl', 'audio/mpegurl']);

function normalizeType(value) {
  return String(value || '').split(';', 1)[0].trim().toLowerCase();
}

function looksHtml(body) {
  const text = Buffer.from(body || '').subarray(0, 64).toString('utf8').trimStart().toLowerCase();
  return text.startsWith('<!doctype html') || text.startsWith('<html') || text.startsWith('<head') || text.startsWith('<script');
}

function validMediaBytes(body, type) {
  const bytes = Buffer.from(body || '');
  if (bytes.length === 0) return false;
  if (bytes.length > 188 && bytes[0] === 0x47 && bytes[188] === 0x47) return true;
  if (bytes.subarray(4, 8).toString('ascii') === 'ftyp') return true;
  if (bytes.subarray(0, 4).toString('hex') === '1a45dfa3') return true;
  if (bytes.subarray(0, 4).toString('ascii') === 'RIFF') return true;
  return false;
}

function diagnosticReason(result) {
  return result.detail ? `${result.reason}: ${result.detail}` : result.reason;
}

function classifyProbe(probe) {
  const status = Number(probe.status || 0);
  const type = normalizeType(probe.contentType);
  if ([401, 403, 405, 429, 503].includes(status)) {
    return { ok: false, conclusive: false, reason: 'blocked-or-unknown', httpCode: status };
  }
  if (!status) return { ok: false, conclusive: false, reason: 'blocked-or-unknown' };
  if (status < 200 || status >= 400) return { ok: false, conclusive: true, reason: `http-${status}`, httpCode: status };
  if (looksHtml(probe.body)) return { ok: false, conclusive: true, reason: 'html', httpCode: status };
  if (HLS_TYPES.has(type) || String(probe.body || '').trimStart().startsWith('#EXTM3U')) {
    const segment = probe.segment;
    if (!segment || segment.status < 200 || segment.status >= 300 || !validMediaBytes(segment.body, normalizeType(segment.contentType) || 'video/mp2t')) {
      return { ok: false, conclusive: true, reason: 'invalid-hls-segment', httpCode: status };
    }
    return { ok: true, conclusive: true, reason: 'hls-segment' };
  }
  if (MEDIA_TYPES.has(type) && validMediaBytes(probe.body, type)) return { ok: true, conclusive: true, reason: 'media' };
  return { ok: false, conclusive: true, reason: 'invalid-media', httpCode: status };
}

function nextHealth(previous = {}, result, now = new Date().toISOString(), runId) {
  const failures = Number(previous.consecutiveFailures || 0);
  const base = { ...previous, lastCheck: now, lastCheckRunId: runId || previous.lastCheckRunId || null, conclusive: result.conclusive };
  if (!result.conclusive) {
    return {
      ...base,
      status: previous.status === 'down' ? 'down' : 'blocked_or_unknown',
      lastError: diagnosticReason(result),
      httpCode: result.httpCode || null,
    };
  }
  if (result.ok) {
    return {
      ...base,
      status: failures > 0 ? 'recovered' : 'active',
      consecutiveFailures: 0,
      firstFailureAt: null,
      lastError: null,
      httpCode: null,
      lastSuccessAt: now,
    };
  }
  const isDistinctRun = !runId || runId !== previous.lastCheckRunId;
  const nextFailures = failures + (isDistinctRun ? 1 : 0);
  const firstFailureAt = previous.firstFailureAt || now;
  const elapsedMs = Date.parse(now) - Date.parse(firstFailureAt);
  // Un NXDOMAIN es una evidencia concluyente de que el host publicado no
  // existe en DNS. No lo dejamos bloqueado indefinidamente: el reemplazo
  // debe poder activarse aunque nunca llegue a responder HTTP.
  const isConfirmedDown = result.permanent === true
    || (nextFailures >= 3 && Number.isFinite(elapsedMs) && elapsedMs >= 12 * 60 * 60 * 1000);
  return {
    ...base,
    status: isConfirmedDown ? 'down' : 'suspected_down',
    consecutiveFailures: nextFailures,
    lastError: diagnosticReason(result),
    httpCode: result.httpCode || null,
    firstFailureAt,
  };
}

function createRunId(now = new Date()) {
  return `${now.toISOString()}-${crypto.randomUUID()}`;
}

async function readPrefix(response, limit = 4096) {
  if (!response.body || typeof response.body.getReader !== 'function') {
    return Buffer.from(await response.arrayBuffer()).subarray(0, limit);
  }
  const reader = response.body.getReader();
  const chunks = [];
  let size = 0;
  try {
    while (size < limit) {
      const part = await reader.read();
      if (part.done) break;
      const chunk = Buffer.from(part.value);
      chunks.push(chunk);
      size += chunk.length;
    }
  } finally {
    await reader.cancel().catch(() => {});
  }
  return Buffer.concat(chunks, Math.min(size, limit)).subarray(0, limit);
}

async function probeUrl(url, { fetchImpl = fetch, timeoutMs = 10000 } = {}) {
  const cookieJar = new Map();
  const defaultCookiePath = (target) => {
    const pathname = new URL(target).pathname || '/';
    const slash = pathname.lastIndexOf('/');
    return slash <= 0 ? '/' : pathname.slice(0, slash);
  };
  const domainMatches = (hostname, domain, hostOnly) => hostOnly
    ? hostname === domain
    : hostname === domain || hostname.endsWith(`.${domain}`);
  const pathMatches = (pathname, cookiePath) => pathname === cookiePath
    || (pathname.startsWith(cookiePath) && (cookiePath.endsWith('/') || pathname[cookiePath.length] === '/'));
  const storeCookies = (response, requestUrl) => {
    const origin = new URL(requestUrl);
    const values = typeof response.headers?.getSetCookie === 'function'
      ? response.headers.getSetCookie()
      : [response.headers?.get('set-cookie')].filter(Boolean);
    for (const value of values) {
      const parts = String(value).split(';').map((part) => part.trim());
      const pair = parts.shift() || '';
      const separator = pair.indexOf('=');
      if (separator <= 0) continue;
      const name = pair.slice(0, separator).trim();
      const cookieValue = pair.slice(separator + 1).trim();
      let domain = origin.hostname.toLowerCase();
      let hostOnly = true;
      let path = defaultCookiePath(origin);
      let secure = false;
      let expiresAt = null;
      for (const attribute of parts) {
        const [rawName, ...rawValue] = attribute.split('=');
        const attributeName = rawName.toLowerCase();
        const attributeValue = rawValue.join('=').trim();
        if (attributeName === 'domain' && attributeValue) {
          const candidate = attributeValue.replace(/^\./, '').toLowerCase();
          if (!domainMatches(origin.hostname.toLowerCase(), candidate, false)) {
            domain = null;
            break;
          }
          domain = candidate;
          hostOnly = false;
        } else if (attributeName === 'path' && attributeValue.startsWith('/')) path = attributeValue;
        else if (attributeName === 'secure') secure = true;
        else if (attributeName === 'max-age' && /^-?\d+$/.test(attributeValue)) expiresAt = Date.now() + Number(attributeValue) * 1000;
        else if (attributeName === 'expires') {
          const parsed = Date.parse(attributeValue);
          if (Number.isFinite(parsed)) expiresAt = parsed;
        }
      }
      if (!domain) continue;
      const key = `${name}\u0000${domain}\u0000${path}`;
      if (expiresAt !== null && expiresAt <= Date.now()) cookieJar.delete(key);
      else cookieJar.set(key, { name, value: cookieValue, domain, hostOnly, path, secure, expiresAt });
    }
  };
  const cookiesFor = (target) => {
    const requestUrl = new URL(target);
    const now = Date.now();
    const matches = [];
    for (const [key, cookie] of cookieJar) {
      if (cookie.expiresAt !== null && cookie.expiresAt <= now) {
        cookieJar.delete(key);
        continue;
      }
      if (cookie.secure && requestUrl.protocol !== 'https:') continue;
      if (!domainMatches(requestUrl.hostname.toLowerCase(), cookie.domain, cookie.hostOnly)) continue;
      if (!pathMatches(requestUrl.pathname || '/', cookie.path)) continue;
      matches.push(cookie);
    }
    matches.sort((left, right) => right.path.length - left.path.length);
    return matches.map((cookie) => `${cookie.name}=${cookie.value}`).join('; ');
  };
  const request = async (target, method = 'GET', contextUrl, readBody = method === 'GET') => {
    const controller = new AbortController();
    let timer;
    const timeout = new Promise((_, reject) => {
      timer = setTimeout(() => {
        controller.abort();
        reject(Object.assign(new Error('request timeout'), { name: 'AbortError' }));
      }, timeoutMs);
    });
    const perform = async () => {
      let currentUrl = new URL(target);
      let referer = contextUrl ? String(contextUrl) : null;
      for (let redirects = 0; redirects <= 5; redirects += 1) {
        const headers = { Accept: '*/*', 'User-Agent': 'HourTV-HealthChecker/1.0' };
        if (method === 'GET') headers.Range = 'bytes=0-2048';
        if (referer) {
          headers.Referer = referer;
          headers.Origin = new URL(referer).origin;
        }
        const cookieHeader = cookiesFor(currentUrl);
        if (cookieHeader) headers.Cookie = cookieHeader;
        const response = await fetchImpl(currentUrl, { method, redirect: 'manual', headers, signal: controller.signal });
        storeCookies(response, currentUrl);
        const location = response.headers?.get('location');
        if (response.status >= 300 && response.status < 400 && location) {
          if (redirects === 5) throw new Error('too many redirects');
          referer = response.url || String(currentUrl);
          currentUrl = new URL(location, referer);
          continue;
        }
        const body = readBody ? await readPrefix(response) : null;
        return { response, body };
      }
      throw new Error('too many redirects');
    };
    try {
      return await Promise.race([perform(), timeout]);
    } finally {
      clearTimeout(timer);
    }
  };
  const responseUrl = (response, fallback) => response.url || String(fallback);
  const firstUriAfter = (lines, marker) => {
    const markerIndex = lines.findIndex((line) => line.startsWith(marker));
    if (markerIndex < 0) return null;
    return lines.slice(markerIndex + 1).find((line) => line && !line.startsWith('#')) || null;
  };
  const firstMediaUri = (lines) => {
    let insideAdBreak = false;
    for (const line of lines) {
      if (line.startsWith('#EXT-X-CUE-OUT')) {
        insideAdBreak = true;
        continue;
      }
      if (line.startsWith('#EXT-X-CUE-IN')) {
        insideAdBreak = false;
        continue;
      }
      if (!insideAdBreak && line && !line.startsWith('#') && !/\.(?:aac|vtt)(?:$|[?#])/i.test(line)) return line;
    }
    return null;
  };
  const fetchHlsSegment = async (initialResponse, initialBody) => {
    let playlistResponse = initialResponse;
    let playlistBody = initialBody;
    for (let depth = 0; depth < 3; depth += 1) {
      const lines = playlistBody.toString('utf8').split(/\r?\n/).map((line) => line.trim());
      const playlistBase = responseUrl(playlistResponse, url);
      const variantUri = firstUriAfter(lines, '#EXT-X-STREAM-INF');
      if (variantUri) {
        const variant = await request(new URL(variantUri, playlistBase), 'GET', playlistBase);
        const variantResponse = variant.response;
        if (variantResponse.status < 200 || variantResponse.status >= 300) {
          return { failure: classifyProbe({ status: variantResponse.status, contentType: variantResponse.headers.get('content-type'), body: variant.body }) };
        }
        playlistResponse = variantResponse;
        playlistBody = variant.body;
        continue;
      }
      const segmentUri = firstMediaUri(lines);
      if (!segmentUri) return null;
      const segment = await request(new URL(segmentUri, playlistBase), 'GET', playlistBase);
      const segmentResponse = segment.response;
      if (segmentResponse.status < 200 || segmentResponse.status >= 300) {
        return { failure: classifyProbe({ status: segmentResponse.status, contentType: segmentResponse.headers.get('content-type'), body: segment.body }) };
      }
      return { segment: {
        status: segmentResponse.status,
        contentType: segmentResponse.headers.get('content-type'),
        body: segment.body,
      } };
    }
    return null;
  };
  const embeddedMediaUrl = (body) => {
    const text = Buffer.from(body || '').toString('utf8');
    const match = text.match(/[\"']file[\"']\s*:\s*[\"'](https?:\/\/[^\"']+(?:\.m3u8|\.mp4)[^\"']*)[\"']/i)
      || text.match(/https?:\/\/[^\"'\s\\]+?(?:\.m3u8|\.mp4)(?:[^\"'\s\\]*)/i);
    return match ? match[1].replace(/\\\\\//g, '/').replace(/\\\//g, '/') : null;
  };
  try {
    let headResponse;
    try {
      headResponse = (await request(url, 'HEAD', null, false)).response;
    } catch {
      // HEAD is advisory. A fresh GET request is the authoritative probe.
    }
    const primary = await request(url, 'GET', headResponse ? responseUrl(headResponse, url) : url);
    const response = primary.response;
    const body = primary.body;
    const result = { status: response.status, contentType: response.headers.get('content-type'), body };
    const type = normalizeType(result.contentType);
    if (response.status >= 200 && response.status < 300 && looksHtml(body)) {
      const mediaUrl = embeddedMediaUrl(body);
      if (mediaUrl) {
        const media = await request(mediaUrl, 'GET', responseUrl(response, url));
        const mediaResponse = media.response;
        const mediaResult = { status: mediaResponse.status, contentType: mediaResponse.headers.get('content-type'), body: media.body };
        const mediaType = normalizeType(mediaResult.contentType);
        if (mediaResponse.status >= 200 && mediaResponse.status < 300 && (HLS_TYPES.has(mediaType) || media.body.toString('utf8').trimStart().startsWith('#EXTM3U'))) {
          const hls = await fetchHlsSegment(mediaResponse, media.body);
          if (hls?.failure) return hls.failure;
          mediaResult.segment = hls?.segment || null;
        }
        const embeddedResult = classifyProbe(mediaResult);
        if (embeddedResult.conclusive || embeddedResult.ok) return { ...embeddedResult, detail: 'embedded-media' };
      }
    }
    if (response.status >= 200 && response.status < 300 && (HLS_TYPES.has(type) || body.toString('utf8').trimStart().startsWith('#EXTM3U'))) {
      const hls = await fetchHlsSegment(response, body);
      if (hls?.failure) return hls.failure;
      result.segment = hls?.segment || null;
    }
    return classifyProbe(result);
  } catch (error) {
    const errorCode = error?.code || error?.cause?.code;
    const dnsFailure = errorCode === 'ENOTFOUND';
    return {
      ok: false,
      conclusive: dnsFailure,
      ...(dnsFailure ? { permanent: true } : {}),
      reason: dnsFailure ? 'dns' : 'blocked-or-unknown',
      detail: error?.name === 'AbortError' ? 'timeout' : (dnsFailure ? 'dns' : 'network'),
    };
  }
}

function loadSources(path) {
  const value = JSON.parse(fs.readFileSync(path, 'utf8'));
  const sources = [];
  const visit = (node) => {
    if (Array.isArray(node)) return node.forEach(visit);
    if (!node || typeof node !== 'object') return;
    if (typeof node.url === 'string' && typeof node.name === 'string') sources.push(node);
    Object.values(node).forEach(visit);
  };
  visit(value);
  return sources;
}

module.exports = { classifyProbe, nextHealth, createRunId, loadSources, probeUrl };

if (require.main === module) {
  const path = process.argv[process.argv.indexOf('--catalog') + 1];
  if (!path) { console.error('Usage: node admin/source-health-check.js --catalog <path>'); process.exitCode = 1; }
  else console.log(JSON.stringify({ dryRun: true, runId: createRunId(), sources: loadSources(path).length }, null, 2));
}
