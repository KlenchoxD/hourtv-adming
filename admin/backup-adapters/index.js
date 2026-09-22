'use strict';

class AdapterRegistry {
  constructor() {
    this.adapters = new Map();
  }

  register(name, adapter) {
    if (!name || !adapter || typeof adapter.searchMovie !== 'function' || typeof adapter.searchEpisode !== 'function') {
      throw new TypeError('Backup adapters must implement searchMovie and searchEpisode');
    }
    this.adapters.set(name, adapter);
    return this;
  }

  get(name) {
    return this.adapters.get(name) || null;
  }
}

function orderProviders(providers) {
  return providers
    .map((provider, index) => ({ provider, index }))
    .filter(({ provider }) => provider.isActive !== false)
    .sort((left, right) => {
      const priority = Number(left.provider.priority ?? Number.MAX_SAFE_INTEGER)
        - Number(right.provider.priority ?? Number.MAX_SAFE_INTEGER);
      return priority || left.index - right.index;
    })
    .map(({ provider }) => provider);
}

function selectFallbackCandidate(providerResults) {
  const orderedProviders = orderProviders(providerResults.map((result) => result.provider));
  const resultsById = new Map(providerResults.map((result) => [result.provider.id, result]));
  for (const provider of orderedProviders) {
    const high = (resultsById.get(provider.id)?.candidates || [])
      .find((candidate) => candidate.confidence === 'high');
    if (high) return high;
  }
  return null;
}

async function searchWithFallback({ providers, registry, kind, query, evaluate }) {
  const method = kind === 'episode' ? 'searchEpisode' : 'searchMovie';
  const attempts = [];
  for (const provider of orderProviders(providers)) {
    const adapter = registry.get(provider.adapterName);
    if (!adapter) {
      attempts.push({ providerId: provider.id, reason: 'adapter_not_registered' });
      continue;
    }
    try {
      const candidates = await adapter[method](query, provider);
      if (!Array.isArray(candidates) || candidates.length === 0) {
        attempts.push({ providerId: provider.id, reason: 'no_candidates' });
        continue;
      }
      const evaluated = candidates.map((candidate) => evaluate(candidate, provider));
      const high = evaluated.find((candidate) => candidate.confidence === 'high');
      attempts.push({ providerId: provider.id, reason: high ? 'high_candidate_found' : 'no_high_candidate', candidates: evaluated });
      if (high) return { candidate: high, attempts };
    } catch (error) {
      attempts.push({ providerId: provider.id, reason: 'adapter_error', error: error.message });
    }
  }
  return { candidate: null, attempts };
}

module.exports = { AdapterRegistry, orderProviders, selectFallbackCandidate, searchWithFallback };
