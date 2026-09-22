'use strict';

const CONFIDENCE_RANK = { rejected: 0, low: 1, medium: 2, high: 3 };
const DEFAULT_MAX_AGE_MS = 24 * 60 * 60 * 1000;

function normalizeTitle(value) {
  return String(value || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
}

function sameValue(left, right) {
  return left == null || right == null || String(left).toLowerCase() === String(right).toLowerCase();
}

function isFresh(checkedAt, now, maxAgeMs = DEFAULT_MAX_AGE_MS) {
  const checked = Date.parse(checkedAt);
  return Number.isFinite(checked) && checked <= now.getTime() && now.getTime() - checked <= maxAgeMs;
}

function evaluateCandidate(target, candidate, options = {}) {
  const now = options.now || new Date();
  const reasons = [];
  const reject = (reason) => ({ confidence: 'rejected', eligibleForBatch: false, reasons: [reason] });

  if (candidate.reproducible !== true || !/^https:\/\//i.test(candidate.url || '')) return reject('URL is not reproducible');
  if (!candidate.type || String(target.type).toLowerCase() !== String(candidate.type).toLowerCase()) return reject('Content type does not match');
  if (target.tmdbId != null && candidate.tmdbId != null && String(target.tmdbId) !== String(candidate.tmdbId)) return reject('TMDB identity does not match');
  if (normalizeTitle(target.title) && normalizeTitle(target.title) !== normalizeTitle(candidate.title)) return reject('Title does not match');
  if (target.year != null && candidate.year != null && Number(target.year) !== Number(candidate.year)) return reject('Year does not match');
  if (target.language != null && candidate.language != null && !sameValue(target.language, candidate.language)) return reject('Language does not match');
  if (target.type === 'episode') {
    if (Number(target.season) !== Number(candidate.season)) return reject('Season does not match');
    if (Number(target.episode) !== Number(candidate.episode)) return reject('Episode does not match');
  }

  const fresh = isFresh(candidate.checkedAt, now, options.maxAgeMs);
  const strongIdentity = (target.tmdbId != null && candidate.tmdbId != null)
    || (target.year != null && candidate.year != null);
  const languageConfirmed = target.language == null || candidate.language != null;
  if (!strongIdentity) reasons.push('Identity evidence is incomplete');
  if (!languageConfirmed) reasons.push('Language evidence is incomplete');
  if (!fresh) reasons.push('Validation is stale');

  const confidence = strongIdentity && fresh && languageConfirmed ? 'high' : strongIdentity ? 'medium' : 'low';
  return { confidence, eligibleForBatch: confidence === 'high', reasons };
}

function canonicalUrl(value) {
  try {
    const url = new URL(value);
    url.hostname = url.hostname.toLowerCase();
    url.hash = '';
    url.pathname = url.pathname.replace(/\/+$/, '') || '/';
    url.searchParams.sort();
    return url.toString();
  } catch (_) {
    return String(value || '').trim();
  }
}

function deduplicateCandidates(candidates) {
  const byUrl = new Map();
  for (const candidate of candidates) {
    const key = canonicalUrl(candidate.url);
    const current = byUrl.get(key);
    const rank = CONFIDENCE_RANK[candidate.confidence] ?? -1;
    const currentRank = current ? (CONFIDENCE_RANK[current.confidence] ?? -1) : -1;
    if (!current || rank > currentRank || (rank === currentRank && (candidate.providerPriority ?? Infinity) < (current.providerPriority ?? Infinity))) {
      byUrl.set(key, candidate);
    }
  }
  return [...byUrl.values()];
}

function buildBatchSummary(candidates, options = {}) {
  const now = options.now || new Date();
  const selectedSources = new Set();
  const included = [];
  const excluded = [];
  for (const candidate of candidates) {
    let exclusionReason = null;
    if (candidate.confidence !== 'high') exclusionReason = 'confidence_not_high';
    else if (!isFresh(candidate.checkedAt, now, options.maxAgeMs)) exclusionReason = 'stale_validation';
    else if (selectedSources.has(candidate.sourceId)) exclusionReason = 'source_already_selected';
    if (exclusionReason) excluded.push({ ...candidate, exclusionReason });
    else {
      selectedSources.add(candidate.sourceId);
      included.push(candidate);
    }
  }
  return { included, excluded, counts: { total: candidates.length, included: included.length, excluded: excluded.length } };
}

module.exports = {
  normalizeTitle,
  isFresh,
  evaluateCandidate,
  deduplicateCandidates,
  buildBatchSummary,
};
