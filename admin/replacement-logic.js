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

function normalizeContentType(value) {
  const normalized = normalizeTitle(value);
  if (['movie', 'film', 'pelicula'].includes(normalized)) return 'movie';
  if (['episode', 'episodio'].includes(normalized)) return 'episode';
  return normalized;
}

function isValidHttpsUrl(value) {
  try {
    const parsed = new URL(value);
    const host = parsed.hostname.toLowerCase().replace(/^\[|\]$/g, '');
    const privateHost = host === 'localhost' || host === '::1' || host.startsWith('fe80:')
      || /^(127\.|0\.0\.0\.0$|10\.|192\.168\.|169\.254\.|172\.(1[6-9]|2\d|3[01])\.)/.test(host);
    return parsed.protocol === 'https:' && !parsed.username && !parsed.password && Boolean(host) && !privateHost;
  } catch (_) {
    return false;
  }
}

function isFresh(checkedAt, now, maxAgeMs = DEFAULT_MAX_AGE_MS) {
  const checked = Date.parse(checkedAt);
  return Number.isFinite(checked) && checked <= now.getTime() && now.getTime() - checked <= maxAgeMs;
}

function evaluateCandidate(target, candidate, options = {}) {
  const now = options.now || new Date();
  const reasons = [];
  const reject = (reason) => ({ confidence: 'rejected', eligibleForBatch: false, trustScore: 0, trustChecks: [{ label: reason, ok: false, weight: 0 }], reasons: [reason] });

  if (candidate.reproducible !== true || !isValidHttpsUrl(candidate.url)) return reject('URL is not reproducible');
  const targetType = normalizeContentType(target.type);
  const candidateType = normalizeContentType(candidate.type);
  if (!candidateType || targetType !== candidateType) return reject('Content type does not match');
  const targetHasTmdb = target.tmdbId != null;
  const candidateHasTmdb = candidate.tmdbId != null;
  if (targetHasTmdb !== candidateHasTmdb || (targetHasTmdb && String(target.tmdbId) !== String(candidate.tmdbId))) return reject('TMDB identity does not match');
  const targetTitle = normalizeTitle(targetType === 'episode' ? (target.seriesTitle || target.title) : target.title);
  const candidateTitle = normalizeTitle(candidateType === 'episode' ? (candidate.seriesTitle || candidate.title) : candidate.title);
  if (!targetTitle || targetTitle !== candidateTitle) return reject('Title does not match');
  if (!targetHasTmdb && (target.year == null || candidate.year == null || Number(target.year) !== Number(candidate.year))) return reject('Year does not match');
  if (targetType === 'episode' && (target.language == null || candidate.language == null)) return reject('Episode language is required');
  if (target.language != null && candidate.language != null && !sameValue(target.language, candidate.language)) return reject('Language does not match');
  if (targetType === 'episode') {
    if (Number(target.season) !== Number(candidate.season)) return reject('Season does not match');
    if (Number(target.episode) !== Number(candidate.episode)) return reject('Episode does not match');
  }

  const fresh = isFresh(candidate.checkedAt, now, options.maxAgeMs);
  const strongIdentity = targetHasTmdb || (target.year != null && candidate.year != null);
  const languageConfirmed = target.language == null || candidate.language != null;
  if (!strongIdentity) reasons.push('Identity evidence is incomplete');
  if (!languageConfirmed) reasons.push('Language evidence is incomplete');
  if (!fresh) reasons.push('Validation is stale');

  const confidence = strongIdentity && fresh && languageConfirmed ? 'high' : strongIdentity ? 'medium' : 'low';
  const checks = [];
  const addCheck = (label, ok, weight, enabled = true) => { if (enabled) checks.push({ label, ok: Boolean(ok), weight }); };
  addCheck('Título exacto', true, 25);
  addCheck('Identidad TMDB exacta', targetHasTmdb && candidateHasTmdb && String(target.tmdbId) === String(candidate.tmdbId), 40, targetHasTmdb);
  addCheck('Año exacto', candidate.year != null && target.year != null && Number(target.year) === Number(candidate.year), targetHasTmdb ? 10 : 35, target.year != null);
  addCheck('Idioma compatible', languageConfirmed && (target.language == null || sameValue(target.language, candidate.language)), 10, target.language != null);
  addCheck('URL reproducible y HTTPS', candidate.reproducible === true && isValidHttpsUrl(candidate.url), 5);
  addCheck('Comprobación reciente', fresh, 10);
  const possible = checks.reduce((sum, check) => sum + check.weight, 0);
  const earned = checks.reduce((sum, check) => sum + (check.ok ? check.weight : 0), 0);
  const trustScore = possible ? Math.round((earned / possible) * 100) : 0;
  return {
    confidence,
    eligibleForBatch: confidence === 'high',
    trustScore,
    trustChecks: checks,
    trustLabel: confidence === 'high' ? `Confianza alta (${trustScore}/100)` : `No elegible (${trustScore}/100)`,
    reasons,
  };
}

function candidateTrustScore(candidate) {
  if (Number.isFinite(Number(candidate?.trustScore))) return Number(candidate.trustScore);
  if (Number.isFinite(Number(candidate?.confidenceScore))) return Number(candidate.confidenceScore);
  return ({ high: 100, medium: 60, low: 25, rejected: 0 }[candidate?.confidence] ?? 0);
}

function canonicalUrl(value) {
  try {
    const url = new URL(value);
    if (url.protocol !== 'https:' || url.username || url.password || !url.hostname) return null;
    url.hostname = url.hostname.toLowerCase();
    url.hash = '';
    url.pathname = url.pathname.replace(/\/+$/, '') || '/';
    url.searchParams.sort();
    return url.toString();
  } catch (_) {
    return null;
  }
}

function deduplicateCandidates(candidates) {
  const seenUrls = new Set();
  const seenSources = new Set();
  const ranked = candidates.map((candidate, index) => ({ candidate, index })).sort((left, right) => {
    const rank = (CONFIDENCE_RANK[right.candidate.confidence] ?? -1) - (CONFIDENCE_RANK[left.candidate.confidence] ?? -1);
    const priority = (left.candidate.providerPriority ?? Infinity) - (right.candidate.providerPriority ?? Infinity);
    return rank || priority || left.index - right.index;
  });
  const result = [];
  for (const { candidate } of ranked) {
    const key = canonicalUrl(candidate.url);
    if (!key || !candidate.sourceId || seenUrls.has(key) || seenSources.has(candidate.sourceId)) continue;
    seenUrls.add(key);
    seenSources.add(candidate.sourceId);
    result.push(candidate);
  }
  return result;
}

function buildBatchSummary(candidates, options = {}) {
  const now = options.now || new Date();
  const selectedSources = new Set();
  const selectedUrls = new Set();
  const included = [];
  const excluded = [];
  for (const candidate of candidates) {
    let exclusionReason = null;
    let evaluated = null;
    const canonicalCandidateUrl = canonicalUrl(candidate.url);
    const target = candidate.sourceId ? options.targetsBySource?.[candidate.sourceId] : null;
    if (!candidate.sourceId) exclusionReason = 'missing_source_id';
    else if (selectedSources.has(candidate.sourceId)) exclusionReason = 'source_already_selected';
    else if (canonicalCandidateUrl && selectedUrls.has(canonicalCandidateUrl)) exclusionReason = 'url_already_selected';
    else if (!target) exclusionReason = 'missing_official_evidence';
    else {
      const expiresAt = Date.parse(candidate.expiresAt);
      if (!Number.isFinite(expiresAt) || expiresAt <= now.getTime()) exclusionReason = 'expired_validation';
    }
    if (!exclusionReason) {
      evaluated = evaluateCandidate(target, candidate, options);
      if (!evaluated.eligibleForBatch) exclusionReason = 'not_eligible';
    }
    if (exclusionReason) excluded.push({ ...candidate, exclusionReason });
    else {
      selectedSources.add(candidate.sourceId);
      selectedUrls.add(canonicalCandidateUrl);
      included.push({ ...candidate, ...evaluated });
    }
  }
  return { included, excluded, counts: { total: candidates.length, included: included.length, excluded: excluded.length } };
}

const HourTVReplacementLogic = {
  normalizeTitle,
  normalizeContentType,
  isValidHttpsUrl,
  isFresh,
  evaluateCandidate,
  candidateTrustScore,
  deduplicateCandidates,
  buildBatchSummary,
};

if (typeof module === 'object' && module.exports) module.exports = HourTVReplacementLogic;
if (typeof globalThis !== 'undefined') globalThis.HourTVReplacementLogic = HourTVReplacementLogic;
