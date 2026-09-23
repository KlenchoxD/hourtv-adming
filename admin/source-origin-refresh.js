const { probeUrl } = require('./source-health-check');

const USER_AGENT = 'HourTV-OriginRefresh/1.0';
const MAX_PAGE_BYTES = 1024 * 1024;

function isSafeHttpsUrl(value) {
  try {
    const parsed = new URL(String(value || ''));
    if (parsed.protocol !== 'https:' || parsed.username || parsed.password) return false;
    const host = parsed.hostname.toLowerCase();
    if (host === 'localhost' || host === '127.0.0.1' || host === '0.0.0.0' || host === '::1') return false;
    if (/^(10\.|192\.168\.|169\.254\.|172\.(1[6-9]|2\d|3[0-1])\.)/.test(host)) return false;
    if (!/^[a-z0-9.-]+$/.test(host)) return false;
    return true;
  } catch {
    return false;
  }
}

function decodeHtml(value) {
  return String(value || '')
    .replace(/&amp;/gi, '&')
    .replace(/&quot;/gi, '"')
    .replace(/&#x2F;/gi, '/')
    .replace(/&#47;/gi, '/')
    .replace(/\\\//g, '/')
    .trim();
}

function normalizedUrl(value, pageUrl) {
  const decoded = decodeHtml(value);
  if (!decoded || decoded.startsWith('#') || decoded.startsWith('javascript:') || decoded.startsWith('data:')) return null;
  try {
    const resolved = new URL(decoded, pageUrl).toString();
    return isSafeHttpsUrl(resolved) ? resolved : null;
  } catch {
    return null;
  }
}

function extractOriginCandidates(html, pageUrl, limit = 40) {
  const text = String(html || '');
  const raw = [];
  const attributePattern = /(?:href|src|data-url|data-src|data-file|file)\s*=\s*["']([^"']+)["']/gi;
  for (let match = attributePattern.exec(text); match && raw.length < limit * 4; match = attributePattern.exec(text)) raw.push(match[1]);
  const absolutePattern = /https?:\/\/[^\s"'<>\\]+/gi;
  for (let match = absolutePattern.exec(text); match && raw.length < limit * 4; match = absolutePattern.exec(text)) raw.push(match[0]);

  const page = new URL(pageUrl);
  const seen = new Set();
  const candidates = [];
  for (const item of raw) {
    const url = normalizedUrl(item, pageUrl);
    if (!url || url === page.toString() || seen.has(url)) continue;
    seen.add(url);
    candidates.push(url);
    if (candidates.length >= limit) break;
  }
  return candidates;
}

async function readPage(url, { fetchImpl = fetch, timeoutMs = 10000 } = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetchImpl(url, {
      method: 'GET',
      redirect: 'follow',
      signal: controller.signal,
      headers: { Accept: 'text/html,application/xhtml+xml,*/*;q=0.8', 'User-Agent': USER_AGENT },
    });
    if (!response.ok) return { ok: false, status: response.status, candidates: [] };
    const text = (await response.text()).slice(0, MAX_PAGE_BYTES);
    return { ok: true, status: response.status, candidates: extractOriginCandidates(text, response.url || url) };
  } catch (error) {
    return { ok: false, status: 0, candidates: [], error: error?.name === 'AbortError' ? 'timeout' : 'network' };
  } finally {
    clearTimeout(timer);
  }
}

function candidateScore(candidate, source) {
  let score = 0;
  try {
    const currentHost = new URL(source.url).hostname.toLowerCase();
    const candidateHost = new URL(candidate).hostname.toLowerCase();
    if (candidateHost === currentHost) score += 100;
    else if (candidateHost.endsWith(`.${currentHost}`) || currentHost.endsWith(`.${candidateHost}`)) score += 60;
    const sourceHint = String(source.name || '').toLowerCase().replace(/[^a-z0-9]+/g, '');
    if (sourceHint && sourceHint.length >= 3 && candidateHost.replace(/[^a-z0-9]+/g, '').includes(sourceHint)) score += 25;
  } catch { /* filtered by normalizedUrl */ }
  if (/\.(?:m3u8|mp4|mpd|webm)(?:[?#]|$)/i.test(candidate)) score += 5;
  return score;
}

async function refreshSourceFromOrigin(source, { probe = probeUrl, fetchImpl = fetch, timeoutMs = 10000 } = {}) {
  const originUrl = String(source?.referer_url || source?.source_page_url || '');
  if (!isSafeHttpsUrl(originUrl)) return { attempted: false, reason: 'no-safe-origin-page', candidatesChecked: 0 };
  if (String(source?.url || '') === originUrl) return { attempted: false, reason: 'origin-is-current-source', candidatesChecked: 0 };

  const discovered = await readPage(originUrl, { fetchImpl, timeoutMs });
  if (!discovered.ok) return { attempted: true, reason: `origin-${discovered.error || `http-${discovered.status}`}`, candidatesChecked: 0 };
  const candidates = discovered.candidates
    .filter((candidate) => candidate !== source.url)
    .sort((left, right) => candidateScore(right, source) - candidateScore(left, source));
  for (const candidate of candidates) {
    const result = await probe(candidate, { timeoutMs });
    if (result?.ok && result.conclusive !== false) {
      return { attempted: true, recovered: true, originUrl, url: candidate, result, candidatesChecked: candidates.indexOf(candidate) + 1 };
    }
  }
  return { attempted: true, recovered: false, originUrl, candidatesChecked: candidates.length, reason: 'no-healthy-server-found' };
}

module.exports = { isSafeHttpsUrl, extractOriginCandidates, refreshSourceFromOrigin };
