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
  if (type === 'video/mp2t') return bytes[0] === 0x47;
  if (bytes.subarray(4, 8).toString('ascii') === 'ftyp') return true;
  if (bytes.subarray(0, 4).toString('hex') === '1a45dfa3') return true;
  if (bytes.subarray(0, 4).toString('ascii') === 'RIFF') return true;
  return type === 'application/octet-stream' && !looksHtml(bytes);
}

function classifyProbe(probe) {
  const status = Number(probe.status || 0);
  const type = normalizeType(probe.contentType);
  if ([401, 403, 429].includes(status)) return { ok: false, conclusive: false, reason: 'access-control', httpCode: status };
  if (status < 200 || status >= 400) return { ok: false, conclusive: true, reason: status ? `http-${status}` : 'network' , httpCode: status || undefined };
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

function nextHealth(previous = {}, result, now = new Date().toISOString()) {
  const failures = Number(previous.consecutiveFailures || 0);
  const base = { ...previous, lastCheck: now, conclusive: result.conclusive };
  if (!result.conclusive) return { ...base, status: previous.status || 'pending' };
  if (result.ok) {
    return { ...base, status: failures > 0 ? 'recovered' : 'active', consecutiveFailures: 0, lastError: null, httpCode: null, lastSuccessAt: now };
  }
  const nextFailures = failures + 1;
  return { ...base, status: nextFailures >= 3 ? 'down' : 'degraded', consecutiveFailures: nextFailures, lastError: result.reason, httpCode: result.httpCode || null, firstFailureAt: previous.firstFailureAt || now };
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
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  const request = (target) => fetchImpl(target, {
    method: 'GET',
    redirect: 'manual',
    headers: { Range: 'bytes=0-2048', Accept: '*/*' },
    signal: controller.signal,
  });
  try {
    const response = await request(url);
    const body = await readPrefix(response);
    const result = { status: response.status, contentType: response.headers.get('content-type'), body };
    const type = normalizeType(result.contentType);
    if (response.status >= 200 && response.status < 300 && (HLS_TYPES.has(type) || body.toString('utf8').trimStart().startsWith('#EXTM3U'))) {
      const line = body.toString('utf8').split(/\r?\n/).find((item) => item && !item.startsWith('#'));
      if (line) {
        const segmentResponse = await request(new URL(line.trim(), url));
        result.segment = {
          status: segmentResponse.status,
          contentType: segmentResponse.headers.get('content-type'),
          body: await readPrefix(segmentResponse),
        };
      }
    }
    return classifyProbe(result);
  } catch (error) {
    return { ok: false, conclusive: true, reason: error?.name === 'AbortError' ? 'timeout' : 'network' };
  } finally {
    clearTimeout(timer);
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
