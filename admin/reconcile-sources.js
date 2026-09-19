const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

function isUUIDv4(uuid) {
  const regex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  return typeof uuid === 'string' && regex.test(uuid);
}

function normalizeUrl(url) {
  try { return new URL(url).href; } catch { return url; }
}

function createIdentity(mediaType, titleIdentity, seasonNumber, episodeNumber, sourceName, url) {
  return {
    mediaType: mediaType || null,
    titleIdentity: titleIdentity || null,
    seasonNumber: seasonNumber !== undefined && seasonNumber !== null ? Number(seasonNumber) : null,
    episodeNumber: episodeNumber !== undefined && episodeNumber !== null ? Number(episodeNumber) : null,
    sourceName: sourceName || null,
    url: url || null
  };
}

function hashIdentity(identity) {
  const str = JSON.stringify([
    identity.mediaType,
    identity.titleIdentity,
    identity.seasonNumber,
    identity.episodeNumber,
    identity.sourceName,
    identity.url
  ]);
  return crypto.createHash('sha256').update(str).digest('hex');
}

function hashEntries(entries) {
  const keys = Object.keys(entries).sort();
  const sortedArr = keys.map(k => entries[k]);
  return crypto.createHash('sha256').update(JSON.stringify(sortedArr)).digest('hex');
}

function writeAtomic(filePath, dataStr) {
  const tmpPath = filePath + '.tmp';
  fs.writeFileSync(tmpPath, dataStr, 'utf8');
  fs.renameSync(tmpPath, filePath);
}

function readManifest(manifestPath) {
  if (!fs.existsSync(manifestPath)) return null;
  try {
    const raw = fs.readFileSync(manifestPath, 'utf8');
    const mf = JSON.parse(raw);
    if (!mf._metadata || !mf.entries) throw new Error('Invalid structure');

    const computedHash = hashEntries(mf.entries);
    if (computedHash !== mf._metadata.entriesSha256) {
      throw new Error('Manifest entriesSha256 mismatch (corruption detected)');
    }
    if (Object.keys(mf.entries).length !== mf.expectedCount) {
      throw new Error('Manifest expectedCount mismatch');
    }

    const uuidToHash = new Map();
    for (const [h, entry] of Object.entries(mf.entries)) {
      if (uuidToHash.has(entry.uuid) && uuidToHash.get(entry.uuid) !== h) {
         throw new Error(`Conflict: UUID ${entry.uuid} associated with multiple identities`);
      }
      uuidToHash.set(entry.uuid, h);
    }
    return mf;
  } catch (e) {
    return { error: e.message };
  }
}

function reconcile(catalogRaw, snapshotInput, options = {}) {
  const catalogHash = crypto.createHash('sha256').update(catalogRaw).digest('hex');
  const catalog = JSON.parse(catalogRaw);

  const hasMetadata = snapshotInput && typeof snapshotInput === 'object' && snapshotInput._metadata;
  const authority = hasMetadata ? snapshotInput._metadata.authority : null;
  const isAuthoritative = authority === 'authoritative';
  const snapshot = hasMetadata && snapshotInput.data ? snapshotInput.data : (Array.isArray(snapshotInput) ? snapshotInput : []);
  const isNonAuthoritative = !isAuthoritative;

  const stats = {
    inspected: { movies: 0, series: 0, liveChannels: 0, sources: 0 },
    matched: 0,
    confirmedLocal: 0,
    new: 0,
    invalidId: 0,
    duplicate: 0,
    ambiguous: 0,
    unmatched: 0,
    pendingSync: 0,
    totalProposedChanges: 0,
    conflicts: []
  };

  const manifestPath = options.manifestPath;
  let manifest = readManifest(manifestPath);
  if (manifest && manifest.error) {
    stats.conflicts.push(`Manifest corrupt: ${manifest.error}`);
    return { stats, catalog, manifest: null };
  }

  if (manifest && manifest._metadata.status === 'planned') {
     if (catalogHash !== manifest._metadata.catalogBaseSha256 && catalogHash !== manifest._metadata.catalogWrittenSha256) {
       stats.conflicts.push(`catalogBaseSha256 mismatch before first write. Expected ${manifest._metadata.catalogBaseSha256} or ${manifest._metadata.catalogWrittenSha256}, got ${catalogHash}`);
     }
  }

  if (options.recoverManifest) {
    if (!isAuthoritative) {
      stats.conflicts.push('Cannot recover manifest: Snapshot is not authoritative.');
      return { stats, catalog, manifest: null };
    }
  }

  const newEntries = {};
  let manifestDirty = false;

  const snapshotMap = { movies: new Map(), series: new Map() };
  if (Array.isArray(snapshot)) {
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
  const identityHashesSeen = new Set();

  let totalSourcesWithId = 0;
  let totalSourcesWithoutId = 0;

  function checkServer(server, type, location, matchCandidates, identity) {
    stats.inspected[type]++;

    if (!server.name || !server.url) {
      stats.conflicts.push(`Invalid structure at ${location}`);
      return;
    }

    const idHash = hashIdentity(identity);
    if (identityHashesSeen.has(idHash)) {
       // Identidades duplicadas (exactamente misma peli/server/url dos veces en el catálogo)
       // Esto puede pasar, pero para el manifiesto, mapeará al mismo UUID.
    }
    identityHashesSeen.add(idHash);

    if (server.id) {
      totalSourcesWithId++;
      if (isUUIDv4(server.id)) {
        if (seenIds.has(server.id)) {
          stats.duplicate++;
          stats.conflicts.push(`Duplicate ID ${server.id} at ${location}`);
        } else {
          seenIds.add(server.id);
          const snapMatch = Array.isArray(snapshot) ? snapshot.find(s => s.id === server.id) : null;

          if (snapMatch) {
            stats.confirmedLocal++;
            stats.matched++;
            if (options.recoverManifest) {
              stats.conflicts.push(`Cannot recover: ID ${server.id} already exists in Supabase, no need to recover it to manifest.`);
            } else if (snapMatch.url !== server.url) {
              // Contradictory match
              stats.conflicts.push(`Contradictory match: Catalog UUID ${server.id} has URL ${server.url}, but Supabase has ${snapMatch.url}`);
            }
          } else {
            // Local UUID NOT in Supabase.
            if (manifest && manifest.entries[idHash]) {
              const mEntry = manifest.entries[idHash];
              if (mEntry.uuid !== server.id) {
                 stats.conflicts.push(`Manifest conflict at ${location}: Catalog has ${server.id}, Manifest has ${mEntry.uuid}`);
                 stats.ambiguous++;
              } else if (hashIdentity(mEntry.identity) !== idHash || mEntry.identity.url !== server.url) {
                 stats.conflicts.push(`Identity change at ${location}`);
                 stats.ambiguous++;
              } else {
                 newEntries[idHash] = mEntry;
                 stats.pendingSync++;
                 stats.totalProposedChanges++;
              }
            } else if (options.recoverManifest) {
              newEntries[idHash] = { identity, hash: idHash, uuid: server.id };
              manifestDirty = true;
            } else {
              stats.unmatched++;
              stats.conflicts.push(`UUID ${server.id} at ${location} not found in Supabase snapshot AND missing from local manifest`);
            }
          }
        }
      } else {
        stats.invalidId++;
        stats.conflicts.push(`Legacy/Invalid ID '${server.id}' at ${location}`);
      }
    } else {
      totalSourcesWithoutId++;
      const exactUrl = server.url;
      const candidatesByUrl = matchCandidates.filter(c => c.url === exactUrl);

      if (candidatesByUrl.length === 1) {
        stats.matched++;
        stats.totalProposedChanges++;
        server.id = candidatesByUrl[0].id;
        if (options.recoverManifest) {
           stats.conflicts.push(`Contradictory match: Source at ${location} has no ID but URL matches Supabase ID ${server.id}`);
        }
      } else if (candidatesByUrl.length > 1) {
        stats.ambiguous++;
        stats.conflicts.push(`Ambiguous match at ${location} (${candidatesByUrl.length} matches for URL)`);
      } else {
        if (manifest && manifest.entries[idHash]) {
           const mEntry = manifest.entries[idHash];
           if (mEntry.uuid) {
              server.id = mEntry.uuid;
              newEntries[idHash] = mEntry;
              stats.new++;
              stats.totalProposedChanges++;
           }
        } else {
           if (isNonAuthoritative || !Array.isArray(snapshot)) {
             stats.unmatched++;
           } else {
             const newUuid = crypto.randomUUID();
             server.id = newUuid;
             const entry = { identity, hash: idHash, uuid: newUuid };
             newEntries[idHash] = entry;
             manifestDirty = true;
             stats.new++;
             stats.totalProposedChanges++;
           }
        }
      }
    }
  }

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
        const iden = createIdentity('movie', key, null, null, s.name, s.url);
        checkServer(s, 'movies', `movies[${mIdx}].servers[${sIdx}]`, candidates, iden);
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
            const iden = createIdentity('series', seriesKey, sea.number, ep.number, srv.name, srv.url);
            checkServer(srv, 'series', `series[${sIdx}].seasons[${seaIdx}].episodes[${epIdx}].servers[${srvIdx}]`, candidates, iden);
          });
        });
      });
    });
  }

  if (Array.isArray(catalog.liveChannels)) {
    catalog.liveChannels.forEach((c, cIdx) => {
      if (Array.isArray(c.servers)) {
        c.servers.forEach((s, sIdx) => {
          const iden = createIdentity('liveChannel', c.id || c.name, null, null, s.name, s.url);
          checkServer(s, 'liveChannels', `liveChannels[${cIdx}].servers[${sIdx}]`, [], iden);
        });
      }
    });
  }

  if (Array.isArray(catalog.sources)) {
    catalog.sources.forEach((s, sIdx) => {
      const iden = createIdentity('source', null, null, null, s.name, s.url);
      checkServer(s, 'sources', `sources[${sIdx}]`, [], iden);
    });
  }

  if (options.recoverManifest && totalSourcesWithoutId > 0 && totalSourcesWithId > 0) {
    stats.conflicts.push('Cannot recover manifest: Catalog contains an inexplicable mix of sources with and without UUIDs.');
  }

  let finalManifest = manifest;
  let simulatedCatalogWrittenSha256 = crypto.createHash('sha256').update(JSON.stringify(catalog, null, 2)).digest('hex');

  if (manifestDirty || !manifest || (manifest && manifest._metadata.status !== 'catalog_written')) {
    finalManifest = {
      _metadata: {
        version: 1,
        catalogBaseSha256: catalogHash,
        catalogWrittenSha256: simulatedCatalogWrittenSha256,
        entriesSha256: hashEntries(newEntries),
        status: 'planned'
      },
      expectedCount: Object.keys(newEntries).length,
      entries: newEntries
    };
  }

  let autoRecoveredPlannedToWritten = false;
  if (manifest && manifest._metadata.status === 'planned' && catalogHash === manifest._metadata.catalogWrittenSha256) {
    // Critical case: Catalog was written, but manifest remained planned.
    // Validate that all UUIDs in the catalog EXACTLY match the planned entries.
    // Since we just ran checkServer, if they didn't match, we'd have conflicts or unmatched.
    if (stats.conflicts.length === 0 && stats.unmatched === 0 && stats.totalProposedChanges === 0) {
      finalManifest._metadata.status = 'catalog_written';
      autoRecoveredPlannedToWritten = true;
    }
  }

  return { stats, catalog, manifest: finalManifest, manifestDirty, autoRecoveredPlannedToWritten };
}

module.exports = { reconcile, isUUIDv4, writeAtomic, readManifest };

if (require.main === module) {
  const args = process.argv.slice(2);
  const isDryRun = args.includes('--dry-run');
  const isRecover = args.includes('--recover-manifest');

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

  const manifestIndex = args.indexOf('--manifest');
  const manifestPath = manifestIndex !== -1 && args[manifestIndex + 1] ?
      path.resolve(process.cwd(), args[manifestIndex + 1]) :
      path.resolve(__dirname, 'reconciliation_manifest.json');

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

  let catalogRaw;
  let snapshot;
  try {
    catalogRaw = fs.readFileSync(catalogPath, 'utf8');
    let snapRaw = fs.readFileSync(snapshotPath, 'utf8');
    if (catalogRaw.charCodeAt(0) === 0xFEFF) catalogRaw = catalogRaw.slice(1);
    if (snapRaw.charCodeAt(0) === 0xFEFF) snapRaw = snapRaw.slice(1);

    snapshot = JSON.parse(snapRaw);
    if (snapshot.value) snapshot = snapshot.value;
  } catch (e) {
    console.error('Error: Invalid JSON files', e.message);
    process.exit(3);
  }

  const { stats, catalog, manifest, manifestDirty, autoRecoveredPlannedToWritten } = reconcile(catalogRaw, snapshot, {
    manifestPath,
    recoverManifest: isRecover
  });

  console.log('--- RECONCILIATION REPORT ---');
  console.log('Sources Inspected:');
  console.log(`  movies: ${stats.inspected.movies}`);
  console.log(`  series: ${stats.inspected.series}`);
  console.log(`  liveChannels: ${stats.inspected.liveChannels}`);
  console.log(`  sources: ${stats.inspected.sources}`);
  console.log('Matched:', stats.matched);
  console.log('Confirmed Local UUIDs:', stats.confirmedLocal);
  console.log('Pending Sync (Local UUID matches Manifest):', stats.pendingSync);
  console.log('New UUIDs needed:', stats.new);
  console.log('Unmatched:', stats.unmatched);
  console.log('Ambiguous:', stats.ambiguous);
  console.log('Invalid/Legacy IDs:', stats.invalidId);
  console.log('Duplicates:', stats.duplicate);
  console.log('Total Proposed Changes:', stats.totalProposedChanges);

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

  if (autoRecoveredPlannedToWritten) {
    if (!isDryRun) {
      writeAtomic(manifestPath, JSON.stringify(manifest, null, 2));
      console.log('\nAction: Auto-recovered manifest status to catalog_written.');
    } else {
      console.log('\nAction: Safe changes are pending (Dry-Run mode: would auto-recover manifest).');
    }
    process.exit(2);
  }

  if (stats.totalProposedChanges > 0 || stats.new > 0 || manifestDirty || isRecover) {
    if (isDryRun) {
      console.log('\nAction: Safe changes are pending (Dry-Run mode, nothing written).');
      process.exit(2);
    } else {
      console.log('\nAction: Writing changes...');
      if (manifest) {
        writeAtomic(manifestPath, JSON.stringify(manifest, null, 2));

        const readMf = readManifest(manifestPath);
        if (readMf.error) {
          console.error('\nERROR: Manifest verification failed after write: ' + readMf.error);
          process.exit(3);
        }
      }

      writeAtomic(catalogPath, JSON.stringify(catalog, null, 2));

      if (manifest && manifest._metadata.status === 'planned') {
        manifest._metadata.status = 'catalog_written';
        writeAtomic(manifestPath, JSON.stringify(manifest, null, 2));
      }

      console.log('Write completed successfully.');
      process.exit(2);
    }
  }

  console.log('\nAction: Catalog is fully reconciled and clean.');
  process.exit(0);
}
