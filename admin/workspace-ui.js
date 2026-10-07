(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.HourTVWorkspaceUI=api})(typeof globalThis!=='undefined'?globalThis:this,function(){
  const escape=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  function imageUrl(value){try{const u=new URL(value);return ['http:','https:'].includes(u.protocol)&&!u.username&&!u.password?u.href:''}catch{return ''}}
  function createWorkspace({root,model,adapter}){
    const el=id=>root.getElementById(id);const state={section:'catalog',type:'all',status:'all',query:'',page:1,pageSize:25};
    let selected=null,selectedUnique=false,rows=[],view=null,timer=null,inspectorSignature='',serverSection='down_servers',connection=null;const busy=new Set();
    for(const button of root.querySelectorAll('[data-action],[data-section]'))button.removeAttribute('onclick');
    el('search').removeAttribute('oninput');el('workspace-import-file').removeAttribute('onchange');
    function navigation(){
      for(const b of el('workspace-tabs').querySelectorAll('[data-section]')){const active=b.dataset.section===state.section;b.classList.toggle('active',active);b.setAttribute('aria-current',active?'page':'false')}
      el('workspace-title').textContent={catalog:'Catálogo',pending:'Pendientes',live:'TV en vivo',servers:'Servidores'}[state.section];
      const counts=adapter.getCounts();
      el('workspace-summary').textContent=`${counts.movies||0} películas · ${counts.series||0} series · ${counts.pending||0} fichas pendientes`;
      const server=state.section==='servers';
      el('workspace-server-tabs').hidden=!server;el('workspace-type').closest('label').hidden=server||state.section==='live';
      el('workspace-state').closest('label').hidden=server||state.section==='live';
      el('workspace-inspector').hidden=server;el('workspace-pagination').hidden=server;
      root.querySelector('.content-layout').style.gridTemplateColumns=server?'minmax(0,1fr)':'';
      root.querySelector('[data-action="add"]').hidden=server;
      root.querySelector('[data-action="copyIptv"]').hidden=state.section!=='live';
      const secondary=[['down_servers','Servidores caídos',counts.down],['backup_providers','Páginas de respaldo',counts.backup],['notifications','Notificaciones',counts.notifications]];
      el('workspace-server-tabs').innerHTML=secondary.map(([id,label,count])=>`<button type="button" data-server-section="${id}" class="${id===serverSection?'active':''}">${label} <small>${count||0}</small></button>`).join('');
    }
    function refreshConnection(operation){
      navigation();const cfg=adapter.getConfig();const configured=cfg.owner&&cfg.repo;
      const context=JSON.stringify([cfg.owner||'',cfg.repo||'',cfg.branch||'master',cfg.path||'catalog.json']);
      if(!connection||connection.context!==context)connection={context,state:configured?'configured':'unconfigured'};
      if(operation&&operation.context===context)connection=operation;
      const repo=el('workspace-repo');repo.textContent=configured?`Repo: ${cfg.owner}/${cfg.repo}`:'Repo: sin configurar';
      if(configured){repo.href=`https://github.com/${encodeURIComponent(cfg.owner)}/${encodeURIComponent(cfg.repo)}`;repo.target='_blank';repo.rel='noopener noreferrer'}else repo.removeAttribute('href');
      el('workspace-branch').textContent='Rama: '+(configured?cfg.branch||'master':'—');el('workspace-path').textContent='Archivo: '+(configured?cfg.path||'catalog.json':'—');
      el('status').textContent={unconfigured:'Sin configurar',configured:'Configurado, sin comprobar',checking:'Comprobando',success:'Última operación correcta',error:'Error'}[connection.state]||'Configurado, sin comprobar';
      el('status').title=connection.state==='error'?connection.message||'No se pudo completar la operación':'';
      const raw=el('sb-gh-raw');raw.textContent=configured?`https://raw.githubusercontent.com/${cfg.owner}/${cfg.repo}/${cfg.branch||'master'}/${cfg.path||'catalog.json'}`:'—';
    }
    function inspector(row){
      const signature=row?row.key+JSON.stringify(row.item):'';if(signature===inspectorSignature&&el('workspace-inspector').childElementCount)return;inspectorSignature=signature;
      if(!row){el('workspace-inspector').innerHTML='<div class="inspector-empty"><h2>Tu contenido, al detalle</h2><p>Selecciona un título para consultar su ficha y abrir el editor.</p></div>';return}
      const i=row.item;const art=imageUrl(i.backdrop)||imageUrl(i.poster);const field=(label,value,wide=false)=>`<div class="${wide?'wide':''}"><dt>${label}</dt><dd>${escape(value||'—')}</dd></div>`;
      const seasons=Array.isArray(i.seasons)?i.seasons:[];const episodeCount=seasons.reduce((n,s)=>n+(Array.isArray(s.episodes)?s.episodes.length:0),0);
      const servers=Array.isArray(i.servers)?i.servers:[];const languages=[...new Set(servers.map(s=>s.language||s.idioma).filter(Boolean))];
      const kind=row.collection==='series'?'Serie':row.collection==='sources'?'Fuente en vivo':'Película';
      el('workspace-inspector').innerHTML=`<h2>${escape(i.title||i.name||'Sin título')}</h2>${art?`<img class="inspector-art" src="${escape(art)}" alt="" loading="lazy">`:'<div class="inspector-art" aria-label="Sin imagen"></div>'}
        <span class="workspace-chip">${kind}</span><small style="color:var(--dim);margin-left:8px">Vista de consulta</small>
        <dl class="inspector-fields">${field('Título',i.title||i.name,true)}${field('Tipo',row.collection==='sources'?i.type||'M3U':kind)}${field('Ficha',row.missing.length?'Incompleta':'Completa')}${row.collection==='sources'?'':field('Año',i.year)+field('Rating',i.rating??'—')+field('Géneros',i.genre,true)}</dl>
        ${row.collection==='series'?`<details><summary>Temporadas y episodios <span class="workspace-chip">${seasons.length} / ${episodeCount}</span></summary>${seasons.slice(0,30).map(s=>`<p>Temporada ${escape(s.number)} · ${(s.episodes||[]).length} episodios</p>`).join('')}</details>`:''}
        <details><summary>${row.collection==='sources'?'Fuente':'Servidores'}</summary><p>${row.collection==='sources'?'Los enlaces y credenciales se gestionan en el editor.':row.collection==='series'?'Consulta los idiomas y enlaces por episodio en el editor.':`${servers.length} servidores · ${escape(languages.join(', ')||'Sin idioma definido')}`}</p></details>
        <details><summary>Información avanzada</summary>${row.collection==='sources'?'<p>Fuente privada. Los datos de acceso no se muestran en esta vista.</p>':`<p>${escape(i.plot||i.description||'Sin sinopsis')}</p><p>Dirección: ${escape(i.director||'—')}</p><p>TMDB: ${escape(i.tmdbId||'Sin vincular')}</p>${row.missing.length?`<p>Falta: ${escape(row.missing.join(', '))}</p>`:''}`}</details>
        <button type="button" class="btn-primary inspector-edit" data-action="edit">Abrir editor</button>`;
    }
    function render(){
      navigation();const catalog=adapter.getCatalog();const base=adapter.getBaseline();rows=model.buildRows(catalog,base);
      const summary=model.summarizeChanges(catalog,base);el('workspace-change-count').textContent=!summary.known?'Base remota no cargada':summary.total?`${summary.total} cambios sin publicar`:'Sin cambios locales';
      if(state.section==='servers'){el('workspace-result-count').textContent='';adapter.renderServerSection(serverSection);return}
      if(selected){const previous=selected;selected=model.resolveSelection(rows,previous.key);if(!selected&&selectedUnique&&previous.item.id!=null){const matches=rows.filter(r=>r.item.id===previous.item.id);if(matches.length===1)selected=matches[0]}}
      view=model.getView(rows,state);state.page=view.page;state.pageSize=view.pageSize;
      el('workspace-result-count').textContent=`${view.total} elementos`;
      el('list').className='workspace-table';
      el('list').innerHTML=view.total?`<table><colgroup><col style="width:48%"><col style="width:15%"><col style="width:27%"><col style="width:10%"></colgroup><thead><tr><th>Título</th><th>Tipo</th><th>Estado</th><th><span class="sr-only">Acciones</span></th></tr></thead><tbody>${view.rows.map(row=>{
        const i=row.item,photo=imageUrl(i.poster),key=escape(row.key);const kind=row.collection==='series'?'Serie':row.collection==='sources'?'En vivo':'Película';
        return `<tr data-row-key="${key}" class="${selected&&selected.key===row.key?'selected':''}"><td><div class="workspace-name">${photo?`<img class="workspace-thumb" src="${escape(photo)}" loading="lazy" alt="">`:'<span class="workspace-thumb" aria-hidden="true"></span>'}<div style="min-width:0"><button type="button" class="title-select" data-select="${key}">${escape(i.title||i.name||'Sin título')}</button><small>${escape(row.collection==='sources'?i.type||'Lista M3U':i.year||'Año pendiente')}</small></div></div></td><td><span class="workspace-chip">${kind}</span></td><td><span class="workspace-chip ${row.missing.length?'incomplete':''}">${row.missing.length?'Ficha incompleta':'Ficha completa'}</span>${['added','modified'].includes(row.change)?'<small class="workspace-chip changed">Cambio local</small>':''}</td><td><button type="button" class="btn-ghost btn-sm" data-edit="${key}" aria-label="Editar ${escape(i.title||i.name||'elemento')}">↗</button></td></tr>`;
      }).join('')}</tbody></table>`:'<div class="empty">No hay resultados para estos filtros.</div>';
      el('workspace-pagination').innerHTML=`<span>${view.total?`${(view.page-1)*view.pageSize+1}–${Math.min(view.page*view.pageSize,view.total)} de ${view.total}`:'0 resultados'}</span><label>Filas <select id="workspace-page-size">${[25,50,100].map(n=>`<option ${n===view.pageSize?'selected':''}>${n}</option>`).join('')}</select></label><div class="workspace-buttons"><button type="button" class="btn-ghost btn-sm" data-page="${view.page-1}" ${view.page===1?'disabled':''}>Anterior</button><span>${view.page} / ${view.pageCount}</span><button type="button" class="btn-ghost btn-sm" data-page="${view.page+1}" ${view.page===view.pageCount?'disabled':''}>Siguiente</button></div>`;
      inspector(selected);
    }
    function setSection(section,subsection){clearTimeout(timer);if(['down_servers','backup_providers','notifications'].includes(subsection))serverSection=subsection;state.section=section;state.query='';state.page=1;state.type='all';state.status='all';el('search').value='';el('workspace-type').value='all';el('workspace-state').value='all';selected=null;render()}
    function setFilters(filters){Object.assign(state,filters,{page:1});render()}
    function setPage(page){state.page=page;render()}
    function select(key){selected=model.resolveSelection(rows,key);selectedUnique=!!selected&&rows.filter(r=>r.item.id===selected.item.id).length===1;render()}
    async function action(name,event){
      if(name==='edit'){if(selected)adapter.openItem(selected);return}
      if(name==='add'){adapter.addItem(state.section==='live'?'sources':state.type==='series'?'series':'movies');return}
      if(busy.has(name))return;
      busy.add(name);const buttons=[...root.querySelectorAll(`[data-action="${name}"]`)];buttons.forEach(b=>b.disabled=true);
      try{await adapter.runAction(name,event)}finally{busy.delete(name);buttons.forEach(b=>b.disabled=false)}
    }
    function click(event){const b=event.target.closest('button');if(!b)return;
      if(b.dataset.section)return setSection(b.dataset.section);
      if(b.dataset.serverSection){serverSection=b.dataset.serverSection;return setSection('servers')}
      if(b.dataset.select)return select(b.dataset.select);
      if(b.dataset.edit){const row=model.resolveSelection(rows,b.dataset.edit);if(row)adapter.openItem(row);return}
      if(b.dataset.page)return setPage(Number(b.dataset.page));
      if(b.dataset.action)action(b.dataset.action,event).catch(e=>adapter.onError&&adapter.onError(e));
    }
    function change(event){if(event.target.id==='workspace-type')setFilters({type:event.target.value});if(event.target.id==='workspace-state')setFilters({status:event.target.value});if(event.target.id==='workspace-page-size')setFilters({pageSize:Number(event.target.value)});if(event.target.id==='workspace-import-file')action('import',event).catch(e=>adapter.onError&&adapter.onError(e))}
    function input(event){if(event.target.id!=='search')return;clearTimeout(timer);timer=setTimeout(()=>setFilters({query:event.target.value}),150)}
    function keydown(event){if(event.target.id==='search'&&event.key==='Enter'){clearTimeout(timer);setFilters({query:event.target.value})}if(event.target.classList.contains('workspace-import')&&['Enter',' '].includes(event.key)){event.preventDefault();el('workspace-import-file').click()}}
    function error(event){if(event.target.tagName==='IMG'&&event.target.closest('#list,#workspace-inspector')){event.target.hidden=true}}
    root.addEventListener('click',click);root.addEventListener('change',change);root.addEventListener('input',input);root.addEventListener('keydown',keydown);root.addEventListener('error',error,true);
    refreshConnection();render();
    return {render,setSection,setFilters,setPage,select,refreshConnection,destroy(){clearTimeout(timer);root.removeEventListener('click',click);root.removeEventListener('change',change);root.removeEventListener('input',input);root.removeEventListener('keydown',keydown);root.removeEventListener('error',error,true)}};
  }
  return {createWorkspace};
});
