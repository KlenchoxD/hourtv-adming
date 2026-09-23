(function(root,factory){
'use strict';
const logic=typeof module==='object'&&module.exports?require('../replacement-logic'):root.HourTVReplacementLogic;
const api=factory(logic);
if(typeof module==='object'&&module.exports)module.exports=api;else root.HourTVBackupAdapterCore=api;
}(typeof globalThis!=='undefined'?globalThis:this,function({ evaluateCandidate }){

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
      .filter((candidate) => candidate.confidence === 'high')
      .sort((left, right) => (Number(right.trustScore || 0) - Number(left.trustScore || 0)) || (Date.parse(right.checkedAt) - Date.parse(left.checkedAt)))[0];
    if (high) return high;
  }
  return null;
}

async function searchWithFallback({ providers, registry, kind, query, now = new Date(), maxAgeMs }) {
  const method = kind === 'episode' ? 'searchEpisode' : 'searchMovie';
  const attempts = [];
  for (const provider of orderProviders(providers)) {
    const adapter = registry.get(provider.adapterName);
    if (!adapter) {
      attempts.push({ providerId: provider.id, providerName: provider.name, priority: provider.priority, reason: 'adapter_not_registered' });
      continue;
    }
    let candidates;
    try {
      candidates = await adapter[method](query, provider);
    } catch (error) {
      attempts.push({ providerId: provider.id, providerName: provider.name, priority: provider.priority, reason: 'adapter_error', error: error.message });
      continue;
    }
    if (!Array.isArray(candidates)) {
      attempts.push({ providerId: provider.id, providerName: provider.name, priority: provider.priority, reason: 'validator_error', error: 'Adapter result must be an array' });
      continue;
    }
    if (candidates.length === 0) {
        attempts.push({ providerId: provider.id, providerName: provider.name, priority: provider.priority, reason: 'no_candidates' });
      continue;
    }
    try {
      if (candidates.some((candidate) => !candidate || typeof candidate !== 'object' || Array.isArray(candidate))) {
        throw new TypeError('Every candidate must be an object');
      }
      const evaluated = candidates.map((candidate) => ({ ...candidate, providerPriority: provider.priority, providerName: provider.name, ...evaluateCandidate(query, candidate, { now, maxAgeMs }) }));
      const high = evaluated.filter((candidate) => candidate.confidence === 'high')
        .sort((left,right)=>(Number(right.trustScore || 0)-Number(left.trustScore || 0)) || (Date.parse(right.checkedAt)-Date.parse(left.checkedAt)))[0];
      attempts.push({ providerId: provider.id, providerName: provider.name, priority: provider.priority, reason: high ? 'high_candidate_found' : 'no_high_candidate', candidates: evaluated, selectedCandidateUrl: high?.url || null });
      if (high) return { candidate: high, attempts, selectedProviderId: provider.id, selectionReason: `Página ${provider.name || provider.id} tiene prioridad ${provider.priority ?? 'definida'} y una coincidencia ${high.trustScore || 100}/100.` };
    } catch (error) {
      attempts.push({ providerId: provider.id, providerName: provider.name, priority: provider.priority, reason: 'validator_error', error: error.message });
    }
  }
  const reason = attempts.length && attempts.every((attempt) => attempt.reason === 'adapter_not_registered')
    ? 'no_registered_adapter'
    : attempts.some((attempt) => attempt.reason === 'no_high_candidate')
      ? 'no_high_candidate'
      : 'no_provider_result';
  return { candidate: null, attempts, reason };
}

return { AdapterRegistry, orderProviders, selectFallbackCandidate, searchWithFallback };
}));
