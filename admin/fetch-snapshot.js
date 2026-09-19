const fs = require('fs');
const path = require('path');

async function fetchSnapshot() {
  const configPath = path.resolve(__dirname, '../config/supabase.local.json');
  let config;
  try {
    const raw = fs.readFileSync(configPath, 'utf8');
    config = JSON.parse(raw);
  } catch (e) {
    console.error('Error reading local config.');
    process.exit(1);
  }

  const url = config.SUPABASE_URL;
  const key = config.SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) {
    console.error('Missing URL or KEY in config.');
    process.exit(1);
  }

  const selectQuery = 'select=id,name,url,titles(media_type,legacy_id,tmdb_id),episodes(episode_number,seasons(season_number,titles(legacy_id,tmdb_id,normalized_title)))';
  const fetchUrl = `${url}/rest/v1/sources?${selectQuery}`;

  let allData = [];
  let page = 0;
  const pageSize = 1000;
  let hasMore = true;

  try {
    while (hasMore) {
      const start = page * pageSize;
      const end = start + pageSize - 1;
      
      const res = await fetch(fetchUrl, {
        headers: {
          'apikey': key,
          'Authorization': `Bearer ${key}`,
          'Range-Unit': 'items',
          'Range': `${start}-${end}`
        }
      });

      if (!res.ok) {
        console.error(`HTTP request failed: ${res.status} ${res.statusText}`);
        process.exit(1);
      }

      const data = await res.json();
      allData = allData.concat(data);

      if (data.length < pageSize) {
        hasMore = false;
      } else {
        page++;
      }
    }
    
    const snapshotObj = {
      _metadata: {
        type: 'RLS-limited snapshot',
        authority: 'rls-limited',
        description: 'Not an authoritative snapshot. Contains only sources visible via anon key (published titles).',
        rowCount: allData.length,
        fetchedAt: new Date().toISOString()
      },
      data: allData
    };

    const tempPath = path.resolve(__dirname, '../supabase_snapshot.json.tmp');
    const finalPath = path.resolve(__dirname, '../supabase_snapshot.json');
    
    fs.writeFileSync(tempPath, JSON.stringify(snapshotObj, null, 2));
    fs.renameSync(tempPath, finalPath);
    
    console.log(`Snapshot fetched successfully. anon_visible_count = ${allData.length}`);
  } catch (e) {
    console.error('Fetch exception:', e.message);
    process.exit(1);
  }
}

fetchSnapshot();
