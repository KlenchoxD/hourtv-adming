const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

// Strictly validates UUIDv4
function isUUIDv4(uuid) {
  const regex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  return typeof uuid === 'string' && regex.test(uuid);
}

function normalizeUrl(url) {
  try {
    return new URL(url).href;
  } catch {
    return url;
  }
}

function reconcile(catalog, snapshotInput) {
  const hasMetadata = snapshotInput && typeof snapshotInput === 'object' && snapshotInput._metadata;
  const authority = hasMetadata ? snapshotInput._metadata.authority : null;
  
  // Requirement: explicit metadata required. If missing or "rls-limited", it's non-authoritative.
  const isAuthoritative = authority === 'authoritative';

  const snapshot = hasMetadata && snapshotInput.data ? snapshotInput.data : (Array.isArray(snapshotInput) ? snapshotInput : []);
  
  const stats = {
    inspected: { movies: 0, series: 0, liveChannels: 0, sources: 0 },
    matched: 0, // UUID confirmed against snapshot or newly matched via URL
    confirmedLocal: 0, // Local UUID valid and confirmed in snapshot
    new: 0, // Authoritatively non-existent counterpart (needs new UUID)
    invalidId: 0, // Local ID is not a UUIDv4
    duplicate: 0, // Found the same ID twice
    ambiguous: 0, // More than one possible counterpart
    unmatched: 0, // Insufficient data or local UUID not found
    totalProposedChanges: 0,
    conflicts: []
  };

  const snapshotMap = { movies: new Map(), series: new Map() };
  if (Array.isArray(snapshot)) {
    // Build lookup from snapshot
    for (const src of snapshot) {
      if (src.titles && src.titles.media_type === 'movie') {
        const key = src.titles.legacy_id || src.titles.tmdb_id?.toString();
        if (key) {
          if (!snapshotMap.movies.has(key)) snapshotMap.movies.set(key, []);
          snapshotMap.movies.get(key).push(src);
        }
      } else if (src.episodes && src.episodes.seasons && src.episodes.seasons.titles) {
        const t = src.episodes.seasons.titles;
        const seriesKey = t.legacy_id || t.tmdb_id?.toString() || t.normalized_title;
        const sNum = src.episodes.seasons.season_number;
        const eNum = src.episodes.episode_number;
        const epKey = `${seriesKey}_S${sNum}_E${eNum}`;
        if (!snapshotMap.series.has(epKey)) snapshotMap.series.set(epKey, []);
        snapshotMap.series.get(epKey).push(src);
      }
    }
  }

  const seenIds = new Set();

  function checkServer(server, type, location, matchCandidates) {
    stats.inspected[type]++;
    
    // Validate structure
    if (!server.name || !server.url) {
      stats.conflicts.push(`Invalid structure at ${location}`);
      return;
    }

    if (server.id) {
      if (isUUIDv4(server.id)) {
        if (seenIds.has(server.id)) {
          stats.duplicate++;
          stats.conflicts.push(`Duplicate ID ${server.id} at ${location}`);
        } else {
          seenIds.add(server.id);
          // Confirm against snapshot
          const snapMatch = Array.isArray(snapshot) ? snapshot.find(s => s.id === server.id) : null;
          if (snapMatch) {
            stats.confirmedLocal++;
            stats.matched++;
          } else {
            // Local UUID valid but not found in snapshot.
            // Even if snapshot is non-authoritative, a known local ID not found is unmatched.
            stats.unmatched++;
            stats.conflicts.push(`UUID ${server.id} at ${location} not found in Supabase snapshot`);
          }
        }
      } else {
        stats.invalidId++;
        stats.conflicts.push(`Legacy/Invalid ID '${server.id}' at ${location}`);
      }
    } else {
      // Local server has NO ID. 
      // Restriction: The URL is used ONLY as a secondary discriminator during this initial migration.
      // Stable content identity -> filter candidates -> exact normalized URL.
      // Once a UUID is assigned, identity will never depend on the URL.
      const normUrl = normalizeUrl(server.url);
      const candidatesByUrl = matchCandidates.filter(c => normalizeUrl(c.url) === normUrl);

      if (candidatesByUrl.length === 1) {
        stats.matched++;
        stats.totalProposedChanges++;
      } else if (candidatesByUrl.length > 1) {
        stats.ambiguous++;
        stats.conflicts.push(`Ambiguous match at ${location} (${candidatesByUrl.length} matches for URL)`);
      } else {
        // No match found. If snapshot is non-authoritative, any absence means unmatched.
        if (isAuthoritative) {
          stats.new++;
          stats.totalProposedChanges++;
        } else {
          stats.unmatched++;
        }
      }
    }
  }

  // Validate top-level collections
  for (const key of ['movies', 'series', 'liveChannels', 'sources']) {
    if (catalog[key] && !Array.isArray(catalog[key])) {
      stats.conflicts.push(`Invalid structure: ${key} is not an array`);
    }
  }

  if (Array.isArray(catalog.movies)) {
    catalog.movies.forEach((m, mIdx) => {
      if (!Array.isArray(m.servers)) return;
      const key = m.id || m.tmdb_id?.toString();
      const candidates = snapshotMap.movies.get(key) || [];
      m.servers.forEach((s, sIdx) => {
        checkServer(s, 'movies', `movies[${mIdx}].servers[${sIdx}]`, candidates);
      });
    });
  }

  if (Array.isArray(catalog.series)) {
    catalog.series.forEach((s, sIdx) => {
      if (!Array.isArray(s.seasons)) return;
      const seriesKey = s.id || s.tmdb_id?.toString() || s.title;
      s.seasons.forEach((sea, seaIdx) => {
        if (!Array.isArray(sea.episodes)) return;
        sea.episodes.forEach((ep, epIdx) => {
          if (!Array.isArray(ep.servers)) return;
          const epKey = `${seriesKey}_S${sea.number}_E${ep.number}`;
          const candidates = snapshotMap.series.get(epKey) || [];
          ep.servers.forEach((srv, srvIdx) => {
            checkServer(srv, 'series', `series[${sIdx}].seasons[${seaIdx}].episodes[${epIdx}].servers[${srvIdx}]`, candidates);
          });
        });
      });
    });
  }

  if (Array.isArray(catalog.liveChannels)) {
    catalog.liveChannels.forEach((c, cIdx) => {
      if (Array.isArray(c.servers)) {
        c.servers.forEach((s, sIdx) => {
          checkServer(s, 'liveChannels', `liveChannels[${cIdx}].servers[${sIdx}]`, []);
        });
      }
    });
  }

  if (Array.isArray(catalog.sources)) {
    catalog.sources.forEach((s, sIdx) => {
      checkServer(s, 'sources', `sources[${sIdx}]`, []);
    });
  }

  return stats;
}

module.exports = { reconcile, isUUIDv4 };

if (require.main === module) {
  const args = process.argv.slice(2);
  if (!args.includes('--dry-run')) {
    console.error('Error: Script must be run with --dry-run in Phase 1.');
    process.exit(1);
  }

  const snapshotIndex = args.indexOf('--supabase-snapshot');
  if (snapshotIndex === -1 || !args[snapshotIndex + 1]) {
    console.error('Error: Missing --supabase-snapshot <ruta>');
    process.exit(1);
  }
  
  const catalogIndex = args.indexOf('--catalog');
  if (catalogIndex === -1 || !args[catalogIndex + 1]) {
    console.error('Error: Missing --catalog <ruta>');
    process.exit(1);
  }

  const snapshotPath = path.resolve(process.cwd(), args[snapshotIndex + 1]);
  if (!fs.existsSync(snapshotPath)) {
    console.error(`Error: Snapshot file not found at ${snapshotPath}`);
    process.exit(1);
  }

  const catalogPath = path.resolve(process.cwd(), args[catalogIndex + 1]);
  if (!fs.existsSync(catalogPath)) {
    console.error(`Error: catalog.json not found at ${catalogPath}`);
    process.exit(1);
  }

  let catalog;
  let snapshot;
  try {
    let catRaw = fs.readFileSync(catalogPath, 'utf8');
    let snapRaw = fs.readFileSync(snapshotPath, 'utf8');
    if (catRaw.charCodeAt(0) === 0xFEFF) catRaw = catRaw.slice(1);
    if (snapRaw.charCodeAt(0) === 0xFEFF) snapRaw = snapRaw.slice(1);
    
    catalog = JSON.parse(catRaw);
    snapshot = JSON.parse(snapRaw);
    if (snapshot.value) snapshot = snapshot.value; // handle powershell ConvertTo-Json wrapping
  } catch (e) {
    console.error('Error: Invalid JSON files', e.message);
    process.exit(3); // 3 for invalid structure
  }

  const stats = reconcile(catalog, snapshot);

  console.log('--- RECONCILIATION REPORT ---');
  console.log('Sources Inspected:');
  console.log(`  movies: ${stats.inspected.movies}`);
  console.log(`  series: ${stats.inspected.series}`);
  console.log(`  liveChannels: ${stats.inspected.liveChannels}`);
  console.log(`  sources: ${stats.inspected.sources}`);
  console.log('Matched:', stats.matched);
  console.log('Confirmed Local UUIDs:', stats.confirmedLocal);
  console.log('New UUIDs needed:', stats.new);
  console.log('Unmatched:', stats.unmatched);
  console.log('Ambiguous:', stats.ambiguous);
  console.log('Invalid/Legacy IDs:', stats.invalidId);
  console.log('Duplicates:', stats.duplicate);
  console.log('Total Proposed Changes:', stats.totalProposedChanges);

  // States:
  // 0: fully reconciled, no changes, no unmatched
  // 2: safe changes proposed
  // 3: invalid, duplicate, ambiguous, invalid snapshot, or unmatched

  if (stats.conflicts.length > 0 || stats.unmatched > 0 || stats.invalidId > 0 || stats.duplicate > 0 || stats.ambiguous > 0) {
    if (stats.conflicts.length > 0) {
      console.error('\nERROR: Conflicts detected:');
      stats.conflicts.forEach(c => console.error('  - ' + c));
    }
    if (stats.unmatched > 0) {
      console.error('\nERROR: Unmatched sources detected. Cannot fully reconcile until all sources are matched or authorized as new.');
    }
    process.exit(3);
  }

  if (stats.totalProposedChanges > 0 || stats.new > 0) {
    console.log('\nAction: Safe changes are pending.');
    process.exit(2);
  }

  console.log('\nAction: Catalog is fully reconciled and clean.');
  process.exit(0);
}
