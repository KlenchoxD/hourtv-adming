(function (root) {
  'use strict';

  let providers = [];
  let notifications = [];
  let candidates = [];
  let healthRows = [];
  let replacementEvents = [];
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
  const callRpc = async (name,args) => unwrap(root.HourTVAdminState.supabase.rpc(name,args));
  const candidateFor = id => candidates.find(candidate => candidate.id === id);
  const sourceFor = id => healthRows.find(source => source.source_id === id);
  const providerAdapterName = provider => provider && (provider.adapter_name || provider.adapterName);
  const providerAdapterReady = provider => Boolean(root.HourTVBackupAdapters && providerAdapterName(provider) && root.HourTVBackupAdapters.get(providerAdapterName(provider)));
  const candidateScore = candidate => root.HourTVReplacementLogic.candidateTrustScore(candidate);
  function ensureNoPendingRecovery(){
    const state=root.HourTVPublishRecovery.loadRecovery(localStorage);if(!state)return true;
    root.toast(state.phase==='pending_publish'?'Primero reintenta la publicación pendiente.':'Primero finaliza la sincronización pendiente.','err');renderRecoveryIndicator();return false;
  }

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
      list.innerHTML = '<div class="admin-toolbar"><button class="btn-primary" onclick="openBackupProviderEditor()">+ Añadir página</button><span class="hint">Regla: se consulta en orden de prioridad; dentro de cada página se elige la coincidencia verificable más reciente. Una página sin adaptador nunca se usa.</span></div>' +
        (providers.length ? '<div class="admin-stack">' + providers.map((provider, index) => `
          <article class="admin-card">
            <div class="admin-card-head"><div><b>${e(provider.name)}</b><div class="hint">${e(provider.base_url || 'Sin URL base')}</div></div>
              <span class="status-badge ${provider.is_active && providerAdapterReady(provider) ? 'status-active' : ''}">${provider.is_active ? 'ACTIVA' : 'INACTIVA'}</span></div>
            <div class="admin-meta"><span>Prioridad ${index + 1}</span><span>Adaptador: ${e(provider.adapter_name)}</span><span>${providerAdapterReady(provider) ? 'ADAPTADOR LISTO' : 'ADAPTADOR NO INSTALADO'}</span><span>Última prueba: ${iso(provider.last_tested_at)}</span><span>Éxitos: ${Number(provider.successful_searches || 0)}</span></div>
            ${!providerAdapterReady(provider) ? '<div class="hint" style="color:var(--warn)">Esta página está guardada, pero el sistema no puede buscar en ella hasta instalar su adaptador real.</div>' : ''}
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
    try {
      const result=await root.HourTVReplacementActions.testProviderConfiguration({provider,registry:root.HourTVBackupAdapters,save:async patch=>unwrap(root.HourTVAdminState.supabase.from('backup_providers').update({last_tested_at:patch.lastTestedAt,last_error:patch.lastError,successful_searches:patch.successfulSearches??provider.successful_searches}).eq('id',id).select('id'))});
      root.toast(result.ok?'Configuración comprobada correctamente':result.error,result.ok?'ok':'err'); await renderBackupProviders();
    }
    catch (error) { root.toast(error.message, 'err'); }
  }

  async function loadReplacementData() {
    const data=await root.HourTVReplacementActions.loadAdminData(root.HourTVAdminState.supabase);
    notifications=data.notifications;candidates=data.candidates;healthRows=data.sources;replacementEvents=data.events;providers=data.providers;
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
      list.innerHTML = `<div class="admin-toolbar"><select onchange="setNotificationFilter('type',this.value)"><option value="all">Todos los tipos</option>${['suspected_down','confirmed_down','replacement_found','recovered','origin_refreshed','backup_provider_error','replacement_unavailable','publish_completed','publish_failed'].map(type => `<option value="${type}" ${notificationType===type?'selected':''}>${type}</option>`).join('')}</select>
        <select onchange="setNotificationFilter('state',this.value)"><option value="all">Todos los estados</option>${['open','processing','resolved','dismissed','failed'].map(state => `<option value="${state}" ${notificationState===state?'selected':''}>${state}</option>`).join('')}</select>
        <button class="btn-primary" onclick="openBatchPreview()" ${high.length ? '' : 'disabled'}>Reemplazar todos (${high.length})</button></div>` +
        (visible.length ? `<div class="admin-stack">${visible.map(notificationCard).join('')}</div>` : '<div class="empty">No hay notificaciones con estos filtros.</div>');
    } catch (error) { list.innerHTML = `<div class="empty" style="color:var(--accent2)">No se pudieron cargar las notificaciones: ${e(error.message)}</div>`; }
  }

  function renderHealthRow(row) {
    const highCandidate = candidates.find(item => item.source_id === row.source_id && item.status === 'pending' && item.confidence === 'high');
    const provider = highCandidate && providers.find(item => item.id === highCandidate.backup_provider_id);
    const replacementButton = highCandidate
      ? `<button class="btn-primary btn-sm" onclick="openSourceReplacement('${row.source_id}')">Reemplazar servidor</button>`
      : `<button class="btn-primary btn-sm" disabled title="Primero pulsa Buscar reemplazo y espera una coincidencia de confianza alta">Reemplazar servidor (requiere candidato)</button>`;
    const candidateHint = highCandidate
      ? `<div class="hint" style="color:var(--ok)">Candidato elegido: ${e(provider?.name || 'Página de respaldo')} · confianza alta (${candidateScore(highCandidate)}/100)</div>`
      : '<div class="hint">No hay candidato verificable todavía. El sistema no elegirá una URL a ciegas.</div>';
    return `<article class="admin-card"><div class="admin-card-head"><div><b>${e(row.source_name)}</b><div class="hint">${e(row.title_name)}${row.episode_id ? ` · T${e(row.season_number)} E${e(row.episode_number)}` : ''}</div></div><span class="status-badge status-${row.health_status === 'down' ? 'down' : 'active'}">${e(row.health_status)}</span></div>
      <div class="admin-meta"><span>HTTP ${e(row.health_http_code || '—')}</span><span>${e(row.health_consecutive_failures)} fallos consecutivos</span><span>Última comprobación: ${iso(row.health_last_check)}</span></div><div class="hint">${e(row.health_last_error || 'Sin error registrado')}</div>${candidateHint}
      <div class="admin-actions"><button class="btn-ghost btn-sm" onclick="requestSourceRecheck('${row.source_id}')">Comprobar otra vez</button>${['down','suspected_down','blocked_or_unknown'].includes(row.health_status)?`<button class="btn-ghost btn-sm" onclick="searchSourceReplacement('${row.source_id}')">${highCandidate ? 'Buscar otro reemplazo' : 'Buscar reemplazo'}</button>${replacementButton}`:''}${notifications.some(n => n.source_id === row.source_id) ? `<button class="btn-ghost btn-sm" onclick="openSourceNotification('${row.source_id}')">Ver notificación</button>` : ''}</div></article>`;
  }

  function notificationCard(notification) {
    const candidate = candidateFor(notification.candidate_id); const source = sourceFor(notification.source_id);
    const provider = candidate && providers.find(item => item.id === candidate.backup_provider_id);
    return `<article class="admin-card ${notification.is_read ? '' : 'notice-unread'}"><div class="admin-card-head"><div><b>${e(notification.notification_type)}</b><div class="notice-message">${e(notification.message)}</div></div><span class="status-badge">${e(notification.status)}</span></div>
      <div class="admin-meta"><span>${iso(notification.created_at)}</span>${source ? `<span>${e(source.title_name)} · ${e(source.source_name)}</span>` : ''}${candidate ? `<span>Confianza: ${e(candidate.confidence)} (${candidateScore(candidate)}/100)</span>${provider ? `<span>Página: ${e(provider.name)} · prioridad ${e(provider.priority)}</span>` : ''}` : ''}</div>
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
      if(!notification||!notification.candidate_id)throw new Error('La notificación no tiene candidato');
      await root.HourTVReplacementActions.discardAtomically({candidateId:notification.candidate_id,notificationId:id,callRpc});
      await renderNotifications();
    } catch (error) { root.toast(error.message, 'err'); }
  }

  function openNotificationDetail(id) {
    const notification = notifications.find(item => item.id === id); if (!notification) return;
    const candidate = candidateFor(notification.candidate_id); const source = sourceFor(notification.source_id);
    document.getElementById('modal').innerHTML = `<div class="modal-head"><h3>Detalle de notificación</h3><button class="btn-ghost btn-sm" onclick="closeModal()">✕</button></div><div class="modal-body">
      <div class="sb-section"><div class="sb-row"><span class="sb-label">Tipo</span><span>${e(notification.notification_type)}</span></div><div class="sb-row"><span class="sb-label">Mensaje</span><span class="sb-value">${e(notification.message)}</span></div><div class="sb-row"><span class="sb-label">Estado</span><span>${e(notification.status)}</span></div></div>
      ${source ? `<div class="sb-section"><div class="sb-title">Servidor afectado</div><div class="sb-row"><span class="sb-label">Contenido</span><span>${e(source.title_name)}</span></div><div class="sb-row"><span class="sb-label">Servidor</span><span>${e(source.source_name)}</span></div><div class="sb-row"><span class="sb-label">Evidencia</span><span>${e(source.health_last_error || '—')} · HTTP ${e(source.health_http_code || '—')} · ${e(source.health_consecutive_failures)} fallos</span></div></div>` : ''}
      ${candidate ? `<div class="sb-section"><div class="sb-title">Reemplazo propuesto</div><div class="sb-row"><span class="sb-label">URL</span><span class="sb-value">${e(candidate.proposed_url)}</span></div><div class="sb-row"><span class="sb-label">Idioma</span><span>${e(candidate.proposed_language_code)}</span></div><div class="sb-row"><span class="sb-label">Confianza</span><span>${e(candidate.confidence)} (${candidateScore(candidate)}/100)</span></div><div class="sb-row"><span class="sb-label">Criterios</span><span>${e((candidate.confidence_reasons || []).join(' · ') || 'Identidad exacta, URL reproducible y prueba reciente')}</span></div><div class="sb-row"><span class="sb-label">Comprobado</span><span>${iso(candidate.checked_at)}</span></div></div>` : ''}
      ${replacementEvents.some(event=>event.source_id===notification.source_id)?`<div class="sb-section"><div class="sb-title">Historial real</div>${replacementEvents.filter(event=>event.source_id===notification.source_id).map(event=>`<div class="sb-row"><span>${e(event.event_type)}</span><span>${iso(event.created_at)}</span></div>`).join('')}</div>`:''}</div>
      <div class="modal-foot"><span></span><button class="btn-primary" onclick="closeModal()">Cerrar</button></div>`;
    document.getElementById('overlay').classList.add('open');
    if (!notification.is_read) toggleNotificationRead(id, true);
  }

  function enrichCandidate(candidate) {
    const source = sourceFor(candidate.source_id); if (!source) throw new Error('No se encontró el servidor oficial asociado');
    return { ...candidate, sourceId: source.source_id, previousUrl: source.source_url, contentType: source.episode_id ? 'episode' : 'movie', tmdbId: source.tmdb_id,
      season: source.season_number, episode: source.episode_number, url: candidate.proposed_url, proposedName: candidate.proposed_name,
      checkedAt: candidate.checked_at, expiresAt: candidate.expires_at, reproducible: candidate.is_reproducible,
      confidence:candidate.confidence,providerAdapterName:(providers.find(p=>p.id===candidate.backup_provider_id)||{}).adapter_name };
  }

  async function revalidateIfNeeded(candidate){
    if(Date.parse(candidate.expiresAt)>Date.now())return candidate;
    const raw=candidateFor(candidate.id),provider=providers.find(p=>p.id===raw.backup_provider_id),source=sourceFor(candidate.sourceId);
    const target={type:candidate.contentType,tmdbId:candidate.tmdbId,title:source.title_name,seriesTitle:source.title_name,year:source.release_year,season:candidate.season,episode:candidate.episode,language:source.language_code};
    const checked=await root.HourTVReplacementActions.revalidateCandidate({candidate,target,provider,registry:root.HourTVBackupAdapters,now:new Date()});
    if(checked.confidence!=='high')throw new Error('No se pudo revalidar el candidato: '+(checked.revalidationReason||checked.reasons||'evidencia insuficiente'));
    await unwrap(root.HourTVAdminState.supabase.from('replacement_candidates').update({proposed_url:checked.url,confidence:'high',confidence_reasons:checked.reasons||[],is_reproducible:true,checked_at:checked.checkedAt,expires_at:checked.expiresAt}).eq('id',candidate.id).select('id'));
    return checked;
  }

  async function replaceFromNotification(notificationId) {
    if (busy||!ensureNoPendingRecovery()) return; const notification = notifications.find(item => item.id === notificationId); const raw = notification && candidateFor(notification.candidate_id);
    if (!raw) return root.toast('La notificación no tiene un candidato disponible', 'err');
    busy = true;
    try {
      const candidate = await revalidateIfNeeded(enrichCandidate(raw));
      const preview=JSON.parse(JSON.stringify(root.HourTVAdminState.catalog)); root.HourTVReplacementAdmin.replaceCatalogSource(preview,candidate);
      const provider=providers.find(item=>item.id===raw.backup_provider_id);
      const outcome=await root.HourTVReplacementActions.applyConfirmedReplacement({candidate,notificationId,confirm:()=>Promise.resolve(confirm(`¿Reemplazar ${raw.proposed_name||'el servidor'} por este candidato?\n\nPágina: ${provider?.name || 'desconocida'} · Prioridad: ${provider?.priority ?? '—'}\nConfianza: alta (${candidateScore(candidate)}/100)\nURL: ${candidate.url}`)),callRpc});
      if(outcome&&outcome.cancelled)return;
      Object.keys(root.HourTVAdminState.catalog).forEach(k=>delete root.HourTVAdminState.catalog[k]);Object.assign(root.HourTVAdminState.catalog,preview);
      root.HourTVPublishRecovery.beginIndividualRecovery(localStorage,candidate.id);root.save();renderRecoveryIndicator();
      root.closeModal(); root.render(); root.toast('Reemplazo aplicado. Hay cambios pendientes de publicar.', 'ok'); await refreshAdminCounts();
    } catch (error) { root.toast('No se aplicó el reemplazo: '+error.message, 'err'); } finally { busy = false; }
  }

  function targetsBySourceFor(list) {
    const result = {};
    list.forEach(raw => { const source = sourceFor(raw.source_id); if (!source) return; result[source.source_id] = { type:source.episode_id ? 'episode' : 'movie', tmdbId:source.tmdb_id,
      title:source.title_name, seriesTitle:source.title_name, year:source.release_year, season:source.season_number, episode:source.episode_number, language:source.language_code }; });
    return result;
  }

  function batchCandidates() { return candidates.filter(item => item.status === 'pending').map(enrichCandidate); }
  function openBatchPreview() {
    if(!ensureNoPendingRecovery())return;
    let list; try { list = batchCandidates(); } catch (error) { return root.toast(error.message, 'err'); }
    const summary = root.HourTVReplacementLogic.buildBatchSummary(list, { now:new Date(), targetsBySource:targetsBySourceFor(candidates) });
    const reasons = summary.excluded.reduce((map, item) => { map[item.exclusionReason] = (map[item.exclusionReason] || 0) + 1; return map; }, {});
    document.getElementById('modal').innerHTML = `<div class="modal-head"><h3>Vista previa: Reemplazar todos</h3><button class="btn-ghost btn-sm" onclick="closeModal()">✕</button></div><div class="modal-body"><div class="batch-summary"><div><b>${summary.counts.total}</b><br>Total</div><div><b>${summary.counts.included}</b><br>Incluidos (high y vigentes)</div><div><b>${summary.counts.excluded}</b><br>Excluidos</div></div>
      ${Object.keys(reasons).length ? `<div class="sb-section"><div class="sb-title">Motivos de exclusión</div>${Object.entries(reasons).map(([reason,count]) => `<div class="sb-row"><span>${e(reason)}</span><b>${count}</b></div>`).join('')}</div>` : ''}<p class="hint">Los cambios se aplicarán como un lote recuperable y el catálogo se publicará una sola vez al finalizar.</p></div>
      <div class="modal-foot"><button class="btn-ghost" onclick="closeModal()">Cancelar</button><button class="btn-primary" onclick="confirmBatchReplacement()" ${summary.included.length ? '' : 'disabled'}>Confirmar ${summary.included.length} reemplazos</button></div>`;
    document.getElementById('overlay').classList.add('open');
  }

  async function confirmBatchReplacement() {
    if (busy||!ensureNoPendingRecovery()) return; busy = true;
    try {
      const rawList=batchCandidates(),list=[];
      for(const candidate of rawList){try{list.push(await revalidateIfNeeded(candidate))}catch(error){candidate.revalidationFailure=error.message}}
      const summary=root.HourTVReplacementLogic.buildBatchSummary(list,{now:new Date(),targetsBySource:targetsBySourceFor(candidates)});
      const preview=JSON.parse(JSON.stringify(root.HourTVAdminState.catalog));for(const candidate of summary.included)root.HourTVReplacementAdmin.replaceCatalogSource(preview,candidate);
      const ids=summary.included.map(c=>c.id);if(!ids.length)throw new Error('Ningún candidato pudo revalidarse como high y vigente');
      const workflow=await root.HourTVReplacementActions.executeBatchWorkflow({candidateIds:ids,callRpc,
        afterApply:async()=>{Object.keys(root.HourTVAdminState.catalog).forEach(k=>delete root.HourTVAdminState.catalog[k]);Object.assign(root.HourTVAdminState.catalog,preview);root.save();},
        publish:async()=>root.publish({throwOnError:true,skipReplacementFinalize:true})});
      const publishError=workflow.publishError;
      root.render(); root.closeModal();
      if(workflow.phase==='pending_finalize'){root.HourTVPublishRecovery.saveRecovery(localStorage,{phase:'pending_finalize',candidateIds:ids,error:workflow.finalizeError&&workflow.finalizeError.message});root.toast('Catálogo publicado; sincronización final pendiente.','err');}
      else if (publishError) { root.HourTVPublishRecovery.saveRecovery(localStorage,{phase:'pending_publish',candidateIds:ids,error:publishError.message}); root.toast('Reemplazos aplicados; publicación pendiente. Puedes reintentar.', 'err'); }
      else { root.HourTVPublishRecovery.clearRecovery(localStorage); root.toast(`${ids.length} reemplazos aplicados y publicados una sola vez.`, 'ok'); }
      renderRecoveryIndicator();
      await renderNotifications();
    } catch (error) { root.save(); root.render(); root.toast('No se aplicó el lote: ' + error.message, 'err'); } finally { busy = false; }
  }
  async function finalizePendingReplacementPublish(succeeded,error){
    if(!root.HourTVAdminState.supabase||!root.HourTVAdminState.session)return;
    const state=root.HourTVPublishRecovery.loadRecovery(localStorage);if(!state)return;
    if(!succeeded){root.HourTVPublishRecovery.saveRecovery(localStorage,{...state,phase:'pending_publish',error:error||'Error de publicación'});renderRecoveryIndicator();return;}
    try{await callRpc('admin_finalize_replacement_publish',{p_candidate_ids:state.candidateIds,p_succeeded:true,p_error:null});root.HourTVPublishRecovery.clearRecovery(localStorage);}
    catch(finalizeError){root.HourTVPublishRecovery.saveRecovery(localStorage,{...state,phase:'pending_finalize',error:finalizeError.message});}
    renderRecoveryIndicator();
  }
  function renderRecoveryIndicator(){
    const state=root.HourTVPublishRecovery.loadRecovery(localStorage);let button=document.getElementById('replacement-recovery-btn');
    if(!state){if(button)button.remove();return;}
    if(!button){button=document.createElement('button');button.id='replacement-recovery-btn';button.className='btn-ghost btn-sm';button.onclick=retryReplacementRecovery;document.querySelector('.header-actions').prepend(button);}
    button.textContent=state.phase==='pending_publish'?'⚠ Reintentar publicación':'⚠ Finalizar sincronización';
    button.title=state.phase==='pending_publish'?'Publicará una vez y luego finalizará notificaciones':'El catálogo ya fue publicado; solo finalizará Supabase';
  }
  async function retryReplacementRecovery(){
    if(busy)return;busy=true;
    try{const result=await root.HourTVPublishRecovery.retryRecovery({storage:localStorage,publish:async()=>root.publish({throwOnError:true,skipReplacementFinalize:true}),callRpc});
      if(result.phase==='complete')root.toast('Publicación y sincronización completadas.','ok');
      else if(result.phase==='pending_finalize')root.toast('Catálogo publicado; sincronización final pendiente.','err');
      else root.toast('La publicación sigue pendiente: '+result.error.message,'err');
    }finally{busy=false;renderRecoveryIndicator();}
  }

  async function renderSourceHealth() {
    const list = document.getElementById('list'); list.className = '';
    if (!requireSession(list)) return;
    list.innerHTML = '<div class="empty">Cargando estado de servidores…</div>';
    try {
      await loadReplacementData();
      const search = (document.getElementById('search').value || '').toLowerCase().trim();
      const visible = healthRows.filter(row => {
        const matchesSearch = !search || `${row.source_name} ${row.title_name}`.toLowerCase().includes(search);
        // Cuando el administrador busca un título concreto desde "down",
        // también mostramos pending/active para poder comprobar una fuente
        // que todavía no ha sido revisada por el sincronizador.
        const matchesState = healthState === 'all' || row.health_status === healthState || (Boolean(search) && healthState === 'down');
        return matchesState && matchesSearch;
      });
      root._downServersCount = healthRows.filter(row => row.health_status === 'down').length; root.renderTabs();
      list.innerHTML = `<div class="admin-toolbar"><select onchange="setHealthState(this.value)">${['all','down','suspected_down','blocked_or_unknown','recovered','pending','active'].map(state => `<option value="${state}" ${healthState===state?'selected':''}>${state === 'all' ? 'Todos los estados' : state}</option>`).join('')}</select>${search && healthState === 'down' ? '<span class="hint">La búsqueda incluye fuentes aún no revisadas para poder comprobarlas.</span>' : ''}</div>` +
        (visible.length ? `<div class="admin-stack">${visible.map(renderHealthRow).join('')}</div>` : '<div class="empty">No hay servidores en este estado.</div>');
    } catch (error) { list.innerHTML = `<div class="empty" style="color:var(--accent2)">No se pudo cargar la salud de servidores: ${e(error.message)}<br><small>Aplica localmente la migración admin_source_health_view si aún no existe.</small></div>`; }
  }

  function setHealthState(value) { healthState = value; renderSourceHealth(); }
  async function requestSourceRecheck(sourceId) {
    try {
      if (root.HourTVAdminState.hasPendingRecovery && root.HourTVAdminState.hasPendingRecovery()) throw new Error('Resuelve primero la recuperación pendiente');
      const source = healthRows.find(row => row.source_id === sourceId);
      if (!source) throw new Error('No se encontró la fuente');
      const session = root.HourTVAdminState.session || {};
      const url = localStorage.getItem('hourtv_sb_url'); const key = localStorage.getItem('hourtv_sb_anon_key');
      const token = localStorage.getItem('hourtv_sb_access_token');
      const payloadSource = { ...source, url: source.url || source.source_url };
      const response = await fetch('/api/health-check', { method:'POST', headers:{'Content-Type':'application/json', apikey:key || '', Authorization:token ? `Bearer ${token}` : ''}, body:JSON.stringify({sourceId, source:payloadSource, supabaseUrl:url}) });
      const result = await response.json(); if (!response.ok) throw new Error(result.error || 'No se pudo comprobar el servidor');
      root.toast(`Comprobación completada: ${result.health.health_status}`, result.health.health_status === 'down' ? 'err' : 'ok'); await renderSourceHealth();
    } catch (error) { root.toast(error.message, 'err'); }
  }
  async function searchSourceReplacement(sourceId) {
    if(!ensureNoPendingRecovery())return;
    const source = healthRows.find(row => row.source_id === sourceId); if (!source) return;
    try {
      if (!providers.length) providers = await unwrap(root.HourTVAdminState.supabase.from('backup_providers').select('*').eq('is_active', true).order('priority'));
      const query={sourceId:source.source_id,type:source.episode_id?'episode':'movie',tmdbId:source.tmdb_id,title:source.title_name,seriesTitle:source.title_name,year:source.release_year,season:source.season_number,episode:source.episode_number,language:source.language_code};
      const result=await root.HourTVReplacementActions.searchReplacement({source:query,providers,registry:root.HourTVBackupAdapters,now:new Date(),api:{persistSearchResult:async payload=>{
        const c=payload.result.candidate;const checks=(c?.trustChecks||[]).filter(check=>check.ok).map(check=>check.label);const candidate=c?{proposed_url:c.url,proposed_name:c.name||null,proposed_language_code:c.language,content_type:query.type,tmdb_id:c.tmdbId,normalized_title:root.HourTVReplacementLogic.normalizeTitle(c.title||c.seriesTitle),release_year:c.year||null,season_number:c.season||null,episode_number:c.episode||null,is_reproducible:true,confidence:c.confidence,confidence_reasons:[...checks,...(c.reasons||[])],checked_at:c.checkedAt,expires_at:c.expiresAt||new Date(Date.parse(c.checkedAt)+86400000).toISOString()}:null;
        const saved=await callRpc('admin_persist_replacement_search',{p_source_id:sourceId,p_provider_id:payload.providerId,p_attempts:payload.result.attempts,p_candidate:candidate});return {candidate:saved&&saved.candidate_id?{...c,id:saved.candidate_id}:null,attempts:payload.result.attempts};
      }}});
      root.toast(result.candidate ? result.message : (result.message || 'No se encontró reemplazo de confianza alta'), result.candidate ? 'ok' : 'err'); await renderSourceHealth();
    } catch (error) { root.toast(error.message, 'err'); }
  }
  function openSourceReplacement(sourceId) {
    const candidate = root.HourTVReplacementActions.selectOptimalCandidate(candidates.filter(item=>item.source_id===sourceId),providers);
    const notification = notifications.find(item => item.source_id === sourceId && item.candidate_id === (candidate && candidate.id));
    if (!candidate || !notification) return root.toast('Todavía no hay un reemplazo de confianza alta disponible', 'err');
    const provider = providers.find(item => item.id === candidate.backup_provider_id);
    document.getElementById('modal').innerHTML = `<div class="modal-head"><h3>Reemplazo recomendado</h3><button class="btn-ghost btn-sm" onclick="closeModal()">✕</button></div><div class="modal-body">
      <div class="sb-section"><div class="sb-title">Decisión automática</div><p class="hint">Se elige la primera página con prioridad disponible que entregue una coincidencia verificable. Si hay varias en la misma página, gana la mayor puntuación y la comprobación más reciente.</p><div class="sb-row"><span class="sb-label">Página elegida</span><b>${e(provider?.name || 'Desconocida')}</b></div><div class="sb-row"><span class="sb-label">Prioridad</span><span>${e(provider?.priority ?? '—')}</span></div><div class="sb-row"><span class="sb-label">Confianza</span><span class="status-badge status-active">ALTA · ${candidateScore(candidate)}/100</span></div><div class="sb-row"><span class="sb-label">URL</span><span class="sb-value">${e(candidate.proposed_url)}</span></div></div>
      <div class="sb-section"><div class="sb-title">Qué se comprobó</div><p class="hint">Identidad del contenido, coincidencia de título/temporada/episodio, idioma cuando aplica, URL HTTPS reproducible y vigencia de la prueba.</p></div></div>
      <div class="modal-foot"><button class="btn-ghost" onclick="closeModal()">Cancelar</button><button class="btn-primary" onclick="replaceFromNotification('${notification.id}')">Confirmar reemplazo</button></div>`;
    document.getElementById('overlay').classList.add('open');
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
  root.finalizePendingReplacementPublish=finalizePendingReplacementPublish;
  root.retryReplacementRecovery=retryReplacementRecovery;
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',renderRecoveryIndicator);else renderRecoveryIndicator();
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', refreshAdminCounts);
  else refreshAdminCounts();
}(window));
