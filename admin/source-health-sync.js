#!/usr/bin/env node
const { nextHealth, probeUrl } = require('./source-health-check');
const { refreshSourceFromOrigin } = require('./source-origin-refresh');
const EMBED_HOSTS = new Set(['barmonrey.com', 'paulinito.com', 'voe.sx', 'streamwish.to', 'vimeus.com', 'primesrc.me']);
function isKnownEmbed(url) {
  try {
    const host = new URL(url).hostname.toLowerCase();
    return [...EMBED_HOSTS].some((name) => host === name || host.endsWith(`.${name}`));
  } catch { return false; }
}

function buildHealthUpdate(previous, result, checkedAt, runId) {
  const health = nextHealth(previous, result, checkedAt, runId);
  return {
    healthStatus: health.status,
    healthLastError: health.lastError ?? null,
    healthHttpCode: result.httpCode ?? health.httpCode ?? null,
    healthConsecutiveFailures: health.consecutiveFailures,
    healthFirstFailureAt: health.firstFailureAt ?? null,
    healthLastSuccessAt: health.lastSuccessAt ?? null,
    healthLastCheck: checkedAt,
    healthLastCheckRunId: health.lastCheckRunId ?? null,
    conclusive: result.conclusive,
    sourceUrl: result.sourceUrl || null,
  };
}

async function persistHealthResults(client, runId, results) {
  await client.query('BEGIN');
  try {
    for (const item of results) {
      const update = buildHealthUpdate(item.previous || {}, item.result, item.checkedAt, runId);
      await client.query(
        `UPDATE public.sources
         SET url = COALESCE($10, url), health_status = $1, health_last_error = $2, health_http_code = $3,
             health_consecutive_failures = $4, health_first_failure_at = $5,
             health_last_success_at = $6, health_last_check = $7,
             health_last_check_run_id = $8, updated_at = now()
         WHERE id = $9`,
        [update.healthStatus, update.healthLastError, update.healthHttpCode,
          update.healthConsecutiveFailures, update.healthFirstFailureAt,
          update.healthLastSuccessAt, update.healthLastCheck,
          update.healthLastCheckRunId, item.id, update.sourceUrl],
      );
      await client.query(
        `INSERT INTO private.source_health_checks
           (source_id, run_id, status_checked, error_msg, http_code, checked_at)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [item.id, runId, update.healthStatus, update.healthLastError,
          update.healthHttpCode, update.healthLastCheck],
      );
      if (update.sourceUrl && update.sourceUrl !== item.previous?.url && (item.result.originRefresh?.originUrl || item.result.originUrl)) {
        const originRefresh = item.result.originRefresh || {};
        await client.query(
          `INSERT INTO public.source_origin_refreshes(source_id, origin_url, previous_url, new_url, evidence)
           VALUES ($1, $2, $3, $4, $5::jsonb)`,
          [item.id, originRefresh.originUrl || item.result.originUrl || item.previous?.url || '', item.previous?.url || '', update.sourceUrl,
            JSON.stringify({ candidatesChecked: originRefresh.candidatesChecked || 0, runId })],
        );
        await client.query(
          `INSERT INTO public.admin_notifications(notification_type, source_id, message)
           VALUES ('origin_refreshed', $1, $2)`,
          [item.id, `La página de origen renovó el servidor automáticamente: ${item.previous?.url || 'URL anterior'} → ${update.sourceUrl}`],
        );
      }
    }
    await client.query("DELETE FROM private.source_health_checks WHERE checked_at < now() - interval '30 days'");
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  }
}

async function loadSources(client, limit) {
  const query = `SELECT id, url, requires_webview, health_status, health_last_error,
      health_http_code, health_consecutive_failures, health_first_failure_at,
      health_last_success_at, health_last_check, health_last_check_run_id,
      referer_url, origin_url
    FROM public.sources WHERE deleted_at IS NULL ORDER BY id LIMIT $1`;
  const { rows } = await client.query(query, [limit]);
  return rows;
}

async function run({ client, limit = 976, dryRun = true, probe = probeUrl, refresh = refreshSourceFromOrigin, autoRefresh = true, now = new Date(), concurrency = 8 }) {
  const sources = await loadSources(client, limit);
  const runId = `${now.toISOString()}-${require('node:crypto').randomUUID()}`;
  const results = [];
  for (let offset = 0; offset < sources.length; offset += concurrency) {
    const batch = sources.slice(offset, offset + concurrency);
    const checked = await Promise.all(batch.map(async (source) => ({
      id: source.id,
      previous: {
        status: source.health_status,
        consecutiveFailures: source.health_consecutive_failures,
        firstFailureAt: source.health_first_failure_at,
        lastSuccessAt: source.health_last_success_at,
        lastCheckRunId: source.health_last_check_run_id,
        url: source.url,
      },
      result: await probe(source.url).then(async (result) => {
        const checked = (source.requires_webview || isKnownEmbed(source.url)) && result.reason === 'html'
          ? { ...result, conclusive: false, reason: 'requires-webview' }
          : result;
        if (!autoRefresh || checked.ok || !source.referer_url) return checked;
        const refreshed = await refresh({ ...source, url: source.url, referer_url: source.referer_url }, { probe });
        return refreshed.recovered
          ? { ...refreshed.result, sourceUrl: refreshed.url, originUrl: refreshed.originUrl, originRefresh: refreshed }
          : { ...checked, originRefresh: refreshed };
      }),
      checkedAt: now.toISOString(),
    })));
    results.push(...checked);
  }
  if (!dryRun) await persistHealthResults(client, runId, results);
  return { runId, dryRun, total: results.length, results };
}

module.exports = { buildHealthUpdate, persistHealthResults, loadSources, run };

if (require.main === module) {
  const dryRun = process.argv.includes('--dry-run');
  const apply = process.argv.includes('--apply');
  if (dryRun === apply || (apply && process.env.CONFIRM_SOURCE_HEALTH_APPLY !== 'true')) {
    console.error('Use exactly one of --dry-run/--apply; --apply requires CONFIRM_SOURCE_HEALTH_APPLY=true');
    process.exitCode = 2;
  } else if (!process.env.SUPABASE_DB_URL) {
    console.error('SUPABASE_DB_URL is required and was not printed or persisted');
    process.exitCode = 2;
  } else {
    const { Client } = require('pg');
    const client = new Client({ connectionString: process.env.SUPABASE_DB_URL, applicationName: 'hourtv-source-health' });
    client.connect()
      .then(() => run({ client, dryRun }))
      .then((report) => {
        console.log(JSON.stringify({ runId: report.runId, dryRun: report.dryRun, total: report.total,
          statuses: report.results.reduce((out, item) => {
            const status = buildHealthUpdate(item.previous, item.result, item.checkedAt, report.runId).healthStatus;
            out[status] = (out[status] || 0) + 1;
            return out;
          }, {}),
          reasons: report.results.reduce((out, item) => {
            const reason = item.result.reason || 'unknown';
            out[reason] = (out[reason] || 0) + 1;
            return out;
          }, {}) }, null, 2));
      })
      .catch((error) => { console.error(`Health sync failed: ${error.message}`); process.exitCode = 4; })
      .finally(() => client.end().catch(() => {}));
  }
}
