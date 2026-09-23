const { probeUrl, nextHealth } = require('../source-health-check');

module.exports = async (req, res) => {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Método no permitido' });
  const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : (req.body || {});
  const sourceId = String(body.sourceId || '');
  const source = body.source || {};
  if (!sourceId || !source.url) return res.status(400).json({ error: 'Faltan sourceId y source.url' });
  const token = String(req.headers.authorization || '');
  const apiKey = String(req.headers.apikey || body.apikey || '');
  const supabaseUrl = String(body.supabaseUrl || '').replace(/\/$/, '');
  if (!token || !apiKey || !supabaseUrl) return res.status(401).json({ error: 'Sesión Supabase requerida' });
  try {
    const result = await probeUrl(source.url, { timeoutMs: 15000 });
    const checkedAt = new Date().toISOString();
    const health = nextHealth({
      status: source.health_status,
      consecutiveFailures: source.health_consecutive_failures,
      firstFailureAt: source.health_first_failure_at,
      lastSuccessAt: source.health_last_success_at,
      lastCheckRunId: source.health_last_check_run_id,
    }, result, checkedAt, `manual-${Date.now()}`);
    const update = {
      health_status: health.status,
      health_last_error: result.detail ? `${result.reason}: ${result.detail}` : result.reason || null,
      health_http_code: result.httpCode || null,
      health_consecutive_failures: health.consecutiveFailures || 0,
      health_first_failure_at: health.firstFailureAt || null,
      health_last_success_at: health.lastSuccessAt || null,
      health_last_check: checkedAt,
      health_last_check_run_id: health.lastCheckRunId,
    };
    const response = await fetch(`${supabaseUrl}/rest/v1/sources?id=eq.${encodeURIComponent(sourceId)}`, {
      method: 'PATCH', headers: { apikey: apiKey, Authorization: token, 'Content-Type': 'application/json', Prefer: 'return=representation' }, body: JSON.stringify(update),
    });
    if (!response.ok) return res.status(response.status).json({ error: 'No se pudo guardar el estado en Supabase' });
    return res.status(200).json({ sourceId, result: { ok: result.ok, conclusive: result.conclusive, reason: result.reason, httpCode: result.httpCode }, health: update });
  } catch (error) {
    return res.status(200).json({ sourceId, result: { ok: false, conclusive: false, reason: 'blocked-or-unknown', detail: error.message } });
  }
};
