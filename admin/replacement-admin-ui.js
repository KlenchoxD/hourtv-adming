(function (root) {
  'use strict';

  let providers = [];
  let notifications = [];
  let candidates = [];
  let healthRows = [];
  let notificationType = 'all';
  let notificationState = 'all';
  let healthState = 'down';
  let busy = false;
  root._unreadNotificationsCount = 0;
  root._backupProvidersCount = 0;

  const e = value => root.esc ? root.esc(value) : String(value ?? '').replace(/[&<>\"]/g, c => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '\"':'&quot;' }[c]));
  const iso = value => value ? new Date(value).toLocaleString() : 'Nunca';
  const requireSession = list => {
    if (root.HourTVAdminState.supabase && root.HourTVAdminState.session) return true;
    list.innerHTML = '<div class="empty">Inicia sesión en Supabase para administrar esta sección.<br><br><button class="btn-primary" onclick="openSupabaseAuth()">Iniciar sesión</button></div>';
    return false;
  };
  const unwrap = async promise => { const result = await promise; if (result.error) throw result.error; return result.data || []; };
  const candidateFor = id => candidates.find(candidate => candidate.id === id);
  const sourceFor = id => healthRows.find(source => source.source_id === id);

  async function refreshAdminCounts() {
    if (!root.HourTVAdminState.supabase || !root.HourTVAdminState.session) return;
    try {
      const [noticeResult, providerResult] = await Promise.all([
        root.HourTVAdminState.supabase.from('admin_notifications').select('*', { count:'exact', head:true }).eq('is_read', false),
        root.HourTVAdminState.supabase.from('backup_providers').select('*', { count:'exact', head:true }),
      ]);
      if (!noticeResult.error) root._unreadNotificationsCount = noticeResult.count || 0;
      if (!providerResult.error) root._backupProvidersCount = providerResult.count || 0;
      root.renderTabs();
    } catch (error) { console.error('No se pudieron actualizar los contadores administrativos', error); }
  }

  async function renderBackupProviders() {
    const list = document.getElementById('list'); list.className = '';
    if (!requireSession(list)) return;
    list.innerHTML = '<div class="empty">Cargando páginas de respaldo…</div>';
    try {
      providers = await unwrap(root.HourTVAdminState.supabase.from('backup_providers').select('*').order('priority'));
      root._backupProvidersCount = providers.length; root.renderTabs();
      list.innerHTML = '<div class="admin-toolbar"><button class="btn-primary" onclick="openBackupProviderEditor()">+ Añadir página</button><span class="hint">La prioridad superior se consulta primero. Cada página necesita un adaptador compatible.</span></div>' +
        (providers.length ? '<div class="admin-stack">' + providers.map((provider, index) => `
          <article class="admin-card">
            <div class="admin-card-head"><div><b>${e(provider.name)}</b><div class="hint">${e(provider.base_url || 'Sin URL base')}</div></div>
              <span class="status-badge ${provider.is_active ? 'status-active' : ''}">${provider.is_active ? 'ACTIVA' : 'INACTIVA'}</span></div>
            <div class="admin-meta"><span>Prioridad ${index + 1}</span><span>Adaptador: ${e(provider.adapter_name)}</span><span>Última prueba: ${iso(provider.last_tested_at)}</span><span>Éxitos: ${Number(provider.successful_searches || 0)}</span></div>
            ${provider.last_error ? `<div class="hint" style="color:var(--warn)">${e(provider.last_error)}</div>` : ''}
            <div class="admin-actions">
              <button class="btn-ghost btn-sm" onclick="moveBackupProvider('${provider.id}',-1)" ${index === 0 ? 'disabled' : ''}>↑ Subir</button>
              <button class="btn-ghost btn-sm" onclick="moveBackupProvider('${provider.id}',1)" ${index === providers.length - 1 ? 'disabled' : ''}>↓ Bajar</button>
              <button class="btn-ghost btn-sm" onclick="openBackupProviderEditor('${provider.id}')">Editar</button>
              <button class="btn-ghost btn-sm" onclick="toggleBackupProvider('${provider.id}')">${provider.is_active ? 'Desactivar' : 'Activar'}</button>
              <button class="btn-ghost btn-sm" onclick="testBackupProvider('${provider.id}')">Probar configuración</button>
              <button class="btn-danger btn-sm" onclick="deleteBackupProvider('${provider.id}')">Eliminar</button>
            </div>
          </article>`).join('') + '</div>' : '<div class="empty">No hay páginas configuradas. Añade una cuando dispongas de un adaptador autorizado.</div>');
    } catch (error) { list.innerHTML = `<div class="empty" style="color:var(--accent2)">No se pudieron cargar las páginas: ${e(error.message)}</div>`; }
  }

  function openBackupProviderEditor(id) {
    const provider = providers.find(item => item.id === id) || {};
    document.getElementById('modal').innerHTML = `<div class="modal-head"><h3>${id ? 'Editar' : 'Añadir'} página de respaldo</h3><button class="btn-ghost btn-sm" onclick="closeModal()">✕</button></div>
      <div class="modal-body"><div class="row"><label>Nombre</label><input id="bp_name" value="${e(provider.name || '')}"></div>
      <div class="row"><label>URL base HTTPS (opcional)</label><input id="bp_url" value="${e(provider.base_url || '')}" placeholder="https://proveedor-autorizado.example"></div>
      <div class="row"><label>Adaptador</label><input id="bp_adapter" value="${e(provider.adapter_name || '')}" placeholder="nombre-del-adaptador"></div>
      <label><input id="bp_active" type="checkbox" ${provider.is_active !== false ? 'checked' : ''}> Activa</label>
      <p class="hint">Guardar la página no crea un scraper. Si el adaptador no está instalado, el panel lo indicará y no buscará contenido.</p></div>
      <div class="modal-foot"><span></span><button class="btn-primary" onclick="saveBackupProvider('${id || ''}')">Guardar</button></div>`;
    document.getElementById('overlay').classList.add('open');
  }

  async function saveBackupProvider(id) {
    if (busy) return; busy = true;
    try {
      const payload = { name: document.getElementById('bp_name').value.trim(), base_url: document.getElementById('bp_url').value.trim() || null,
        adapter_name: document.getElementById('bp_adapter').value.trim().toLowerCase(), is_active: document.getElementById('bp_active').checked };
      if (!payload.name || !/^[a-z0-9][a-z0-9-]*$/.test(payload.adapter_name)) throw new Error('Completa el nombre y usa un identificador de adaptador válido');
      if (payload.base_url && !/^https:\/\//i.test(payload.base_url)) throw new Error('La URL base debe usar HTTPS');
      if (id) await unwrap(root.HourTVAdminState.supabase.from('backup_providers').update(payload).eq('id', id).select('*'));
      else await unwrap(root.HourTVAdminState.supabase.from('backup_providers').insert({ ...payload, priority: providers.length }).select('*'));
      root.closeModal(); root.toast('Página guardada', 'ok'); await renderBackupProviders();
    } catch (error) { root.toast(error.message, 'err'); } finally { busy = false; }
  }

  async function moveBackupProvider(id, direction) {
    if (busy) return; busy = true;
    try {
      const reordered = root.HourTVReplacementAdmin.reorderProviders(providers, id, direction);
      providers = await root.HourTVReplacementAdmin.persistProviderOrder(reordered, async (providerId, patch) => {
        await unwrap(root.HourTVAdminState.supabase.from('backup_providers').update(patch).eq('id', providerId).select('id'));
      });
      root.toast('Prioridad actualizada', 'ok'); await renderBackupProviders();
    } catch (error) { root.toast('No se pudo reordenar: ' + error.message, 'err'); await renderBackupProviders(); } finally { busy = false; }
  }

  async function toggleBackupProvider(id) {
    const provider = providers.find(item => item.id === id); if (!provider) return;
    try { await unwrap(root.HourTVAdminState.supabase.from('backup_providers').update({ is_active: !provider.is_active }).eq('id', id).select('id')); await renderBackupProviders(); }
    catch (error) { root.toast(error.message, 'err'); }
  }

  async function deleteBackupProvider(id) {
    if (!confirm('¿Eliminar esta página de respaldo? La operación puede fallar si tiene candidatos asociados.')) return;
    try { await unwrap(root.HourTVAdminState.supabase.from('backup_providers').delete().eq('id', id).select('id')); root.toast('Página eliminada', 'ok'); await renderBackupProviders(); }
    catch (error) { root.toast(error.message, 'err'); }
  }

  async function testBackupProvider(id) {
    const provider = providers.find(item => item.id === id); if (!provider) return;
    const registry = root.HourTVBackupAdapters;
    const adapter = registry && (registry.get ? registry.get(provider.adapter_name) : registry[provider.adapter_name]);
    const patch = { last_tested_at: new Date().toISOString(), last_error: adapter ? null : `No hay un adaptador compatible instalado para “${provider.adapter_name}”` };
    try { await unwrap(root.HourTVAdminState.supabase.from('backup_providers').update(patch).eq('id', id).select('id')); root.toast(adapter ? 'Adaptador disponible' : patch.last_error, adapter ? 'ok' : 'err'); await renderBackupProviders(); }
    catch (error) { root.toast(error.message, 'err'); }
  }

  async function loadReplacementData() {
    const [noticeData, candidateData, sourceData] = await Promise.all([
      unwrap(root.HourTVAdminState.supabase.from('admin_notifications').select('*').order('created_at', { ascending:false })),
      unwrap(root.HourTVAdminState.supabase.from('replacement_candidates').select('*').order('created_at', { ascending:false })),
      unwrap(root.HourTVAdminState.supabase.from('admin_source_health_view').select('*').order('health_last_check', { ascending:false })),
    ]);
    notifications = noticeData; candidates = candidateData; healthRows = sourceData;
    root._unreadNotificationsCount = notifications.filter(item => !item.is_read).length;
    root._downServersCount = healthRows.filter(item => item.health_status === 'down').length;
    root.renderTabs();
  }

  async function renderNotifications() {
    const list = document.getElementById('list'); list.className = '';
    if (!requireSession(list)) return;
    list.innerHTML = '<div class="empty">Cargando notificaciones…</div>';
    try {
      await loadReplacementData();
      const visible = notifications.filter(item => (notificationType === 'all' || item.notification_type === notificationType) && (notificationState === 'all' || item.status === notificationState));
      const high = candidates.filter(candidate => candidate.status === 'pending' && candidate.confidence === 'high');
      list.innerHTML = `<div class="admin-toolbar"><select onchange="setNotificationFilter('type',this.value)"><option value="all">Todos los tipos</option>${['suspected_down','confirmed_down','replacement_found','recovered','backup_provider_error','replacement_unavailable','publish_completed','publish_failed'].map(type => `<option value="${type}" ${notificationType===type?'selected':''}>${type}</option>`).join('')}</select>
        <select onchange="setNotificationFilter('state',this.value)"><option value="all">Todos los estados</option>${['open','processing','resolved','dismissed','failed'].map(state => `<option value="${state}" ${notificationState===state?'selected':''}>${state}</option>`).join('')}</select>
        <button class="btn-primary" onclick="openBatchPreview()" ${high.length ? '' : 'disabled'}>Reemplazar todos (${high.length})</button></div>` +
        (visible.length ? `<div class="admin-stack">${visible.map(notificationCard).join('')}</div>` : '<div class="empty">No hay notificaciones con estos filtros.</div>');
    } catch (error) { list.innerHTML = `<div class="empty" style="color:var(--accent2)">No se pudieron cargar las notificaciones: ${e(error.message)}</div>`; }
  }

  function notificationCard(notification) {
    const candidate = candidateFor(notification.candidate_id); const source = sourceFor(notification.source_id);
    return `<article class="admin-card ${notification.is_read ? '' : 'notice-unread'}"><div class="admin-card-head"><div><b>${e(notification.notification_type)}</b><div class="notice-message">${e(notification.message)}</div></div><span class="status-badge">${e(notification.status)}</span></div>
      <div class="admin-meta"><span>${iso(notification.created_at)}</span>${source ? `<span>${e(source.title_name)} · ${e(source.source_name)}</span>` : ''}${candidate ? `<span>Confianza: ${e(candidate.confidence)}</span>` : ''}</div>
      <div class="admin-actions"><button class="btn-ghost btn-sm" onclick="toggleNotificationRead('${notification.id}',${notification.is_read ? 'false' : 'true'})">${notification.is_read ? 'Marcar no leída' : 'Marcar leída'}</button>
      <button class="btn-ghost btn-sm" onclick="openNotificationDetail('${notification.id}')">Ver detalles</button>
      ${candidate && candidate.status === 'pending' ? `<button class="btn-primary btn-sm" onclick="replaceFromNotification('${notification.id}')">Reemplazar</button><button class="btn-danger btn-sm" onclick="dismissNotification('${notification.id}')">Descartar</button>` : ''}</div></article>`;
  }

  function setNotificationFilter(kind, value) { if (kind === 'type') notificationType = value; else notificationState = value; renderNotifications(); }
  async function toggleNotificationRead(id, read) {
    try { await unwrap(root.HourTVAdminState.supabase.from('admin_notifications').update({ is_read: read, read_at: read ? new Date().toISOString() : null }).eq('id', id).select('id')); await renderNotifications(); }
    catch (error) { root.toast(error.message, 'err'); }
  }
  async function dismissNotification(id) {
    const notification = notifications.find(item => item.id === id);
    try {
      await unwrap(root.HourTVAdminState.supabase.from('admin_notifications').update({ status:'dismissed', is_read:true, read_at:new Date().toISOString() }).eq('id', id).select('id'));
      if (notification && notification.candidate_id) await unwrap(root.HourTVAdminState.supabase.from('replacement_candidates').update({ status:'discarded' }).eq('id', notification.candidate_id).select('id'));
      await renderNotifications();
    } catch (error) { root.toast(error.message, 'err'); }
  }

  function openNotificationDetail(id) {
    const notification = notifications.find(item => item.id === id); if (!notification) return;
    const candidate = candidateFor(notification.candidate_id); const source = sourceFor(notification.source_id);
    document.getElementById('modal').innerHTML = `<div class="modal-head"><h3>Detalle de notificación</h3><button class="btn-ghost btn-sm" onclick="closeModal()">✕</button></div><div class="modal-body">
      <div class="sb-section"><div class="sb-row"><span class="sb-label">Tipo</span><span>${e(notification.notification_type)}</span></div><div class="sb-row"><span class="sb-label">Mensaje</span><span class="sb-value">${e(notification.message)}</span></div><div class="sb-row"><span class="sb-label">Estado</span><span>${e(notification.status)}</span></div></div>
      ${source ? `<div class="sb-section"><div class="sb-title">Servidor afectado</div><div class="sb-row"><span class="sb-label">Contenido</span><span>${e(source.title_name)}</span></div><div class="sb-row"><span class="sb-label">Servidor</span><span>${e(source.source_name)}</span></div><div class="sb-row"><span class="sb-label">Evidencia</span><span>${e(source.health_last_error || '—')} · HTTP ${e(source.health_http_code || '—')} · ${e(source.health_consecutive_failures)} fallos</span></div></div>` : ''}
      ${candidate ? `<div class="sb-section"><div class="sb-title">Reemplazo propuesto</div><div class="sb-row"><span class="sb-label">URL</span><span class="sb-value">${e(candidate.proposed_url)}</span></div><div class="sb-row"><span class="sb-label">Idioma</span><span>${e(candidate.proposed_language_code)}</span></div><div class="sb-row"><span class="sb-label">Confianza</span><span>${e(candidate.confidence)}</span></div><div class="sb-row"><span class="sb-label">Comprobado</span><span>${iso(candidate.checked_at)}</span></div></div>` : ''}</div>
      <div class="modal-foot"><span></span><button class="btn-primary" onclick="closeModal()">Cerrar</button></div>`;
    document.getElementById('overlay').classList.add('open');
    if (!notification.is_read) toggleNotificationRead(id, true);
  }

  function enrichCandidate(candidate) {
    const source = sourceFor(candidate.source_id); if (!source) throw new Error('No se encontró el servidor oficial asociado');
    return { ...candidate, sourceId: source.source_id, previousUrl: source.source_url, contentType: source.episode_id ? 'episode' : 'movie', tmdbId: source.tmdb_id,
      season: source.season_number, episode: source.episode_number, url: candidate.proposed_url, proposedName: candidate.proposed_name,
      checkedAt: candidate.checked_at, expiresAt: candidate.expires_at, reproducible: candidate.is_reproducible };
  }

  async function persistApplied(candidate, change, notificationId) {
    const now = new Date().toISOString();
    await unwrap(root.HourTVAdminState.supabase.from('sources').update({ url: change.next.url, name: change.next.name, health_status:'active', health_consecutive_failures:0, health_last_error:null }).eq('id', candidate.sourceId).select('id'));
    try {
      await unwrap(root.HourTVAdminState.supabase.from('replacement_candidates').update({ status:'applied' }).eq('id', candidate.id).select('id'));
      await unwrap(root.HourTVAdminState.supabase.from('source_replacement_events').insert({ source_id:candidate.sourceId, candidate_id:candidate.id, event_type:'applied', previous_state:change.previous, resulting_state:change.next }).select('id'));
      if (notificationId) await unwrap(root.HourTVAdminState.supabase.from('admin_notifications').update({ status:'resolved', is_read:true, read_at:now }).eq('id', notificationId).select('id'));
    } catch (error) {
      await root.HourTVAdminState.supabase.from('sources').update({ url:change.previous.url, name:change.previous.name }).eq('id', candidate.sourceId).select('id');
      throw error;
    }
  }

  async function replaceFromNotification(notificationId) {
    if (busy) return; const notification = notifications.find(item => item.id === notificationId); const raw = notification && candidateFor(notification.candidate_id);
    if (!raw) return root.toast('La notificación no tiene un candidato disponible', 'err');
    busy = true;
    try {
      const candidate = enrichCandidate(raw);
      await root.HourTVReplacementAdmin.applyReplacement({ catalog:root.HourTVAdminState.catalog, candidate, now:new Date(),
        revalidate: async () => { throw new Error('El candidato venció. Usa “Buscar reemplazo” para generar una validación nueva.'); },
        persist: ({ candidate:ready, previous, next }) => persistApplied(ready, { previous, next }, notificationId),
        markPending: async () => { localStorage.setItem('hourtv_replacements_pending_publish', 'true'); root.save(); },
      });
      root.closeModal(); root.render(); root.toast('Reemplazo aplicado. Hay cambios pendientes de publicar.', 'ok'); await refreshAdminCounts();
    } catch (error) { root.toast(error.message, 'err'); } finally { busy = false; }
  }

  function targetsBySourceFor(list) {
    const result = {};
    list.forEach(raw => { const source = sourceFor(raw.source_id); if (!source) return; result[source.source_id] = { type:source.episode_id ? 'episode' : 'movie', tmdbId:source.tmdb_id,
      title:source.title_name, seriesTitle:source.title_name, year:source.release_year, season:source.season_number, episode:source.episode_number, language:source.language_code }; });
    return result;
  }

  function batchCandidates() { return candidates.filter(item => item.status === 'pending').map(enrichCandidate); }
  function openBatchPreview() {
    let list; try { list = batchCandidates(); } catch (error) { return root.toast(error.message, 'err'); }
    const summary = root.HourTVReplacementLogic.buildBatchSummary(list, { now:new Date(), targetsBySource:targetsBySourceFor(candidates) });
    const reasons = summary.excluded.reduce((map, item) => { map[item.exclusionReason] = (map[item.exclusionReason] || 0) + 1; return map; }, {});
    document.getElementById('modal').innerHTML = `<div class="modal-head"><h3>Vista previa: Reemplazar todos</h3><button class="btn-ghost btn-sm" onclick="closeModal()">✕</button></div><div class="modal-body"><div class="batch-summary"><div><b>${summary.counts.total}</b><br>Total</div><div><b>${summary.counts.included}</b><br>Incluidos (high y vigentes)</div><div><b>${summary.counts.excluded}</b><br>Excluidos</div></div>
      ${Object.keys(reasons).length ? `<div class="sb-section"><div class="sb-title">Motivos de exclusión</div>${Object.entries(reasons).map(([reason,count]) => `<div class="sb-row"><span>${e(reason)}</span><b>${count}</b></div>`).join('')}</div>` : ''}<p class="hint">Los cambios se aplicarán como un lote recuperable y el catálogo se publicará una sola vez al finalizar.</p></div>
      <div class="modal-foot"><button class="btn-ghost" onclick="closeModal()">Cancelar</button><button class="btn-primary" onclick="confirmBatchReplacement()" ${summary.included.length ? '' : 'disabled'}>Confirmar ${summary.included.length} reemplazos</button></div>`;
    document.getElementById('overlay').classList.add('open');
  }

  async function confirmBatchReplacement() {
    if (busy) return; busy = true; const persisted = [];
    try {
      const list = batchCandidates();
      const result = await root.HourTVReplacementAdmin.applyReplacementBatch({ catalog:root.HourTVAdminState.catalog, candidates:list, targetsBySource:targetsBySourceFor(candidates), now:new Date(),
        persist: async ({ candidate, previous, next }) => { const notice = notifications.find(item => item.candidate_id === candidate.id); await persistApplied(candidate, { previous, next }, notice && notice.id); persisted.push({ candidate, previous, next }); },
        rollbackPersisted: async applied => { for (const item of applied.reverse()) { await root.HourTVAdminState.supabase.from('sources').update({ url:item.previous.url, name:item.previous.name }).eq('id', item.candidate.sourceId).select('id'); await root.HourTVAdminState.supabase.from('replacement_candidates').update({ status:'pending' }).eq('id', item.candidate.id).select('id'); await root.HourTVAdminState.supabase.from('source_replacement_events').insert({ source_id:item.candidate.sourceId, candidate_id:item.candidate.id, event_type:'rolled_back', previous_state:item.next, resulting_state:item.previous }).select('id'); } },
        publish: async () => root.publish({ throwOnError:true }),
      });
      root.save(); root.render(); root.closeModal();
      if (result.publishError) { localStorage.setItem('hourtv_replacements_pending_publish','true'); root.toast('Reemplazos guardados; falló la publicación y puedes reintentar.', 'err'); }
      else { localStorage.removeItem('hourtv_replacements_pending_publish'); root.toast(`${result.applied.length} reemplazos aplicados y publicados una sola vez.`, 'ok'); }
      await renderNotifications();
    } catch (error) { root.save(); root.render(); root.toast('Se revirtió el lote: ' + error.message, 'err'); } finally { busy = false; }
  }

  async function renderSourceHealth() {
    const list = document.getElementById('list'); list.className = '';
    if (!requireSession(list)) return;
    list.innerHTML = '<div class="empty">Cargando estado de servidores…</div>';
    try {
      await loadReplacementData();
      const search = (document.getElementById('search').value || '').toLowerCase().trim();
      const visible = healthRows.filter(row => (healthState === 'all' || row.health_status === healthState) && (!search || `${row.source_name} ${row.title_name}`.toLowerCase().includes(search)));
      root._downServersCount = healthRows.filter(row => row.health_status === 'down').length; root.renderTabs();
      list.innerHTML = `<div class="admin-toolbar"><select onchange="setHealthState(this.value)">${['all','down','suspected_down','blocked_or_unknown','recovered'].map(state => `<option value="${state}" ${healthState===state?'selected':''}>${state === 'all' ? 'Todos los estados' : state}</option>`).join('')}</select></div>` +
        (visible.length ? `<div class="admin-stack">${visible.map(row => `<article class="admin-card"><div class="admin-card-head"><div><b>${e(row.source_name)}</b><div class="hint">${e(row.title_name)}${row.episode_id ? ` · T${e(row.season_number)} E${e(row.episode_number)}` : ''}</div></div><span class="status-badge status-${row.health_status === 'down' ? 'down' : 'active'}">${e(row.health_status)}</span></div>
          <div class="admin-meta"><span>HTTP ${e(row.health_http_code || '—')}</span><span>${e(row.health_consecutive_failures)} fallos consecutivos</span><span>Última comprobación: ${iso(row.health_last_check)}</span></div><div class="hint">${e(row.health_last_error || 'Sin error registrado')}</div>
          <div class="admin-actions"><button class="btn-ghost btn-sm" onclick="requestSourceRecheck('${row.source_id}')">Comprobar otra vez</button><button class="btn-ghost btn-sm" onclick="searchSourceReplacement('${row.source_id}')">Buscar reemplazo</button><button class="btn-primary btn-sm" onclick="openSourceReplacement('${row.source_id}')">Reemplazar servidor</button>${notifications.some(n => n.source_id === row.source_id) ? `<button class="btn-ghost btn-sm" onclick="openSourceNotification('${row.source_id}')">Ver notificación</button>` : ''}</div></article>`).join('')}</div>` : '<div class="empty">No hay servidores en este estado.</div>');
    } catch (error) { list.innerHTML = `<div class="empty" style="color:var(--accent2)">No se pudo cargar la salud de servidores: ${e(error.message)}<br><small>Aplica localmente la migración admin_source_health_view si aún no existe.</small></div>`; }
  }

  function setHealthState(value) { healthState = value; renderSourceHealth(); }
  async function requestSourceRecheck(sourceId) {
    try { await unwrap(root.HourTVAdminState.supabase.from('sources').update({ health_status:'pending', health_last_error:null }).eq('id', sourceId).select('id')); root.toast('Servidor marcado para una nueva comprobación', 'ok'); await renderSourceHealth(); }
    catch (error) { root.toast(error.message, 'err'); }
  }
  async function searchSourceReplacement(sourceId) {
    const source = healthRows.find(row => row.source_id === sourceId); if (!source) return;
    try {
      if (!providers.length) providers = await unwrap(root.HourTVAdminState.supabase.from('backup_providers').select('*').eq('is_active', true).order('priority'));
      const registry = root.HourTVBackupAdapters;
      const compatible = providers.filter(provider => registry && (registry.get ? registry.get(provider.adapter_name) : registry[provider.adapter_name]));
      if (!compatible.length) throw new Error('No hay páginas activas con un adaptador compatible. Configúralas en “Páginas de respaldo”.');
      throw new Error('Los adaptadores instalados deben ejecutar la búsqueda desde el monitor seguro; el panel no extrae páginas directamente.');
    } catch (error) { root.toast(error.message, 'err'); }
  }
  function openSourceReplacement(sourceId) {
    const candidate = candidates.find(item => item.source_id === sourceId && item.status === 'pending' && item.confidence === 'high');
    const notification = notifications.find(item => item.source_id === sourceId && item.candidate_id === (candidate && candidate.id));
    if (!candidate || !notification) return root.toast('Todavía no hay un reemplazo de confianza alta disponible', 'err');
    replaceFromNotification(notification.id);
  }
  function openSourceNotification(sourceId) {
    const notification = notifications.find(item => item.source_id === sourceId);
    if (!notification) return root.toast('No hay notificación relacionada', 'err');
    root.HourTVAdminState.activeTab = 'notifications'; root.renderTabs(); renderNotifications().then(() => openNotificationDetail(notification.id));
  }

  root.renderBackupProviders = renderBackupProviders; root.openBackupProviderEditor = openBackupProviderEditor; root.saveBackupProvider = saveBackupProvider;
  root.moveBackupProvider = moveBackupProvider; root.toggleBackupProvider = toggleBackupProvider; root.deleteBackupProvider = deleteBackupProvider; root.testBackupProvider = testBackupProvider;
  root.renderNotifications = renderNotifications; root.setNotificationFilter = setNotificationFilter; root.toggleNotificationRead = toggleNotificationRead;
  root.dismissNotification = dismissNotification; root.openNotificationDetail = openNotificationDetail; root.replaceFromNotification = replaceFromNotification;
  root.openBatchPreview = openBatchPreview; root.confirmBatchReplacement = confirmBatchReplacement; root.refreshAdminCounts = refreshAdminCounts;
  root.renderDownServers = renderSourceHealth; root.setHealthState = setHealthState; root.requestSourceRecheck = requestSourceRecheck;
  root.searchSourceReplacement = searchSourceReplacement; root.openSourceReplacement = openSourceReplacement; root.openSourceNotification = openSourceNotification;
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', refreshAdminCounts);
  else refreshAdminCounts();
}(window));
