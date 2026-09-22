'use strict';

// Template only. Copy this adapter and implement searches for an authorized provider.
// It deliberately has no domain and performs no network requests.
module.exports = {
  name: 'example-provider',
  isTemplate: true,
  async searchMovie(_query, _provider) {
    return [];
  },
  async searchEpisode(_query, _provider) {
    return [];
  },
};
