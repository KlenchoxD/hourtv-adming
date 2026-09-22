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
  const isConfirmedDown = nextFailures >= 3 && Number.isFinite(elapsedMs) && elapsedMs >= 12 * 60 * 60 * 1000;
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
  const storeCookies = (response) => {
    const values = typeof response.headers?.getSetCookie === 'function'
      ? response.headers.getSetCookie()
      : [response.headers?.get('set-cookie')].filter(Boolean);
    for (const value of values) {
      const pair = String(value).split(';', 1)[0];
      const separator = pair.indexOf('=');
      if (separator > 0) cookieJar.set(pair.slice(0, separator).trim(), pair.slice(separator + 1).trim());
    }
  };
  const request = async (target, method = 'GET', contextUrl) => {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    const headers = {
      Accept: '*/*',
      'User-Agent': 'HourTV-HealthChecker/1.0',
    };
    if (method === 'GET') headers.Range = 'bytes=0-2048';
    if (contextUrl) {
      headers.Referer = String(contextUrl);
      headers.Origin = new URL(contextUrl).origin;
    }
    if (cookieJar.size > 0) {
      headers.Cookie = [...cookieJar].map(([name, value]) => `${name}=${value}`).join('; ');
    }
    try {
      const response = await fetchImpl(target, { method, redirect: 'follow', headers, signal: controller.signal });
      storeCookies(response);
      return response;
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
        const variantResponse = await request(new URL(variantUri, playlistBase), 'GET', playlistBase);
        playlistResponse = variantResponse;
        playlistBody = await readPrefix(variantResponse);
        continue;
      }
      const segmentUri = firstMediaUri(lines);
      if (!segmentUri) return null;
      const segmentResponse = await request(new URL(segmentUri, playlistBase), 'GET', playlistBase);
      return {
        status: segmentResponse.status,
        contentType: segmentResponse.headers.get('content-type'),
        body: await readPrefix(segmentResponse),
      };
    }
    return null;
  };
  try {
    let headResponse;
    try {
      headResponse = await request(url, 'HEAD');
    } catch {
      // HEAD is advisory. A fresh GET request is the authoritative probe.
    }
    const response = await request(url, 'GET', headResponse ? responseUrl(headResponse, url) : url);
    const body = await readPrefix(response);
    const result = { status: response.status, contentType: response.headers.get('content-type'), body };
    const type = normalizeType(result.contentType);
    if (response.status >= 200 && response.status < 300 && (HLS_TYPES.has(type) || body.toString('utf8').trimStart().startsWith('#EXTM3U'))) {
      result.segment = await fetchHlsSegment(response, body);
    }
    return classifyProbe(result);
  } catch (error) {
    return {
      ok: false,
      conclusive: false,
      reason: 'blocked-or-unknown',
      detail: error?.name === 'AbortError' ? 'timeout' : (error?.code === 'ENOTFOUND' ? 'dns' : 'network'),
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
