const catalogBaselineKey='hourtv_admin_base';
const catalogBaselineStore=window.HourTvCatalogBaselineStore||null;
let catalogBase;
let catalogBaseGeneration=0;
let catalogBaseContext=null;
let catalogBaseOrigin=catalogContext(cfg);
function catalogContext(value){return JSON.stringify([value.owner||'',value.repo||'',value.branch||'master',value.path||'catalog.json']);}
function notifyCatalogEvent(name,detail){if(typeof window.dispatchEvent==='function'&&typeof CustomEvent==='function')window.dispatchEvent(new CustomEvent(name,{detail}));}
async function baselineFingerprint(value){
  if(typeof crypto==='undefined'||!crypto.subtle)return null;
  const bytes=new TextEncoder().encode(JSON.stringify(value));
  return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes)),b=>b.toString(16).padStart(2,'0')).join('');
}
async function restoredBaseContext(value){try{const meta=JSON.parse(localStorage.getItem('hourtv_admin_base_context')||'null');return meta&&meta.hash&&meta.hash===await baselineFingerprint(value)?meta.context:null}catch{return null}}
function getTrustedCatalogBase(){return catalogBaseContext===catalogContext(cfg)?catalogBase:null;}

async function restoreCatalogBase(){
  const generation=catalogBaseGeneration;
  try{
    const stored=catalogBaselineStore&&await catalogBaselineStore.get();
    if(catalogBaseGeneration!==generation)return;
    if(stored&&typeof stored==='object'){
      const context=await restoredBaseContext(stored);
      if(catalogBaseGeneration!==generation)return;
      catalogBase=stored;
      catalogBaseContext=context;
      catalogBaseGeneration++;
      try{localStorage.removeItem(catalogBaselineKey)}catch(e){}
      notifyCatalogEvent('hourtv:catalog-base-changed',{});
      return;
    }
  }catch(e){console.warn('No se pudo leer la base de comparación desde IndexedDB.',e)}

  if(catalogBaseGeneration!==generation)return;
  try{
    const raw=localStorage.getItem(catalogBaselineKey);
    if(!raw)return;
    const legacy=JSON.parse(raw);
    if(!legacy||typeof legacy!=='object')return;
    const context=await restoredBaseContext(legacy);
    if(catalogBaseGeneration!==generation)return;
    catalogBase=legacy;
    catalogBaseContext=context;
    catalogBaseGeneration++;
    if(catalogBaselineStore){
      try{
        await catalogBaselineStore.set(legacy);
        localStorage.removeItem(catalogBaselineKey);
      }catch(e){console.warn('La base se mantiene en memoria; no se pudo migrar a IndexedDB.',e)}
    }
    notifyCatalogEvent('hourtv:catalog-base-changed',{});
  }catch(e){console.warn('No se pudo migrar la base de comparación anterior.',e)}
}

const catalogBaseReady=restoreCatalogBase();

async function persistCatalogBase(value,context=catalogContext(cfg)){
  catalogBase=value;
  catalogBaseContext=context;
  catalogBaseOrigin=context;
  catalogBaseGeneration++;
  const generation=catalogBaseGeneration;
  if(!catalogBaselineStore){notifyCatalogEvent('hourtv:catalog-base-changed',{});return false;}
  try{
    await catalogBaselineStore.set(value);
    if(catalogBaseGeneration!==generation)return false;
    try{localStorage.removeItem(catalogBaselineKey)}catch(e){}
    try{const hash=await baselineFingerprint(value);if(hash&&catalogBaseGeneration===generation)localStorage.setItem('hourtv_admin_base_context',JSON.stringify({context,hash}));}catch(e){}
    if(catalogBaseGeneration!==generation)return false;
    notifyCatalogEvent('hourtv:catalog-base-changed',{});
    return true;
  }catch(e){
    console.warn('La base queda disponible en esta sesión, pero no se pudo guardar en IndexedDB.',e);
    notifyCatalogEvent('hourtv:catalog-base-changed',{});
    return false;
  }
}

const publishCatalogSafely=CatalogSync.createPublisher();
let publishing=false;

// catalog.json se sirve por raw.githubusercontent.com, cuya CDN puede
// tardar minutos en propagar un cambio y de forma desigual por región.
// Esta copia en Supabase (lectura directa a Postgres, sin CDN) es lo que
// la app consulta primero para que lo publicado se vea al instante.
// Best-effort: si falla (sin sesión Supabase, sin red), no debe romper
// la publicación real en GitHub, que es la que ya funcionaba antes.
async function syncCatalogSnapshotToSupabase(jsonString){
  if(!supabase||!sbSession){toast('Catálogo publicado en GitHub, pero no en Supabase: sin sesión iniciada.','warn');return}
  try{
    const updated=new Date().toISOString();
    const upd=await supabase.from('catalog_snapshot').update({content:jsonString,updated_at:updated}).eq('id',1);
    if(upd.error){toast('No se sincronizó a Supabase (update): '+upd.error.message,'warn');return}
    if(!upd.data||upd.data.length===0){
      const ins=await supabase.from('catalog_snapshot').insert({id:1,content:jsonString,updated_at:updated});
      if(ins.error){toast('No se sincronizó a Supabase (insert): '+ins.error.message,'warn');return}
    }
    toast('Catálogo sincronizado a Supabase: se verá al instante en la app.','ok');
  }catch(e){toast('No se sincronizó a Supabase: '+e.message,'warn');console.error('syncCatalogSnapshotToSupabase',e)}
}
async function publish(options){
  options=options||{};
  if(!cfg.token){const e=new Error('Configura GitHub primero');toast(e.message,'err');openConfig();if(options.throwOnError)throw e;return false}
  if(publishing){const e=new Error('Ya hay una publicación en curso.');toast(e.message,'warn');if(options.throwOnError)throw e;return false}
  publishing=true;
  const operationConfig={...cfg};const operationContext=catalogContext(operationConfig);
  notifyCatalogEvent('hourtv:github-operation',{context:operationContext,state:'checking'});
  try{
    await catalogBaseReady;
    if(catalogContext(cfg)!==operationContext)throw new Error('La configuración cambió. Vuelve a publicar desde el repositorio actual.');
    const pending=JSON.parse(JSON.stringify(catalog));
    const deleting=new Set(deletedIds);
    const outcome=await publishCatalogSafely({base:(catalogBaseContext||catalogBaseOrigin)===operationContext?catalogBase:null,local:pending,deleted:deleting,
      read:async()=>{
        const res=await ghApi('GET',undefined,operationConfig);
        if(res.status===404)return {catalog:{},sha:undefined};
        if(!res.ok)throw new Error('No se pudo leer el catálogo actual ('+res.status+'). No se sobrescribió.');
        const data=await res.json();
        if(!data.sha)throw new Error('Respuesta de catálogo incompleta.');
        let contentStr;
        if(typeof data.content==='string'&&data.content.length>0){
          contentStr=data.content;
        }else{
          const bRes=await fetch(`https://api.github.com/repos/${operationConfig.owner}/${operationConfig.repo}/git/blobs/${data.sha}`,{
            headers:{Authorization:`Bearer ${operationConfig.token}`,Accept:'application/vnd.github+json'}
          });
          if(!bRes.ok)throw new Error('Error al leer catálogo extenso ('+bRes.status+').');
          const bData=await bRes.json();
          contentStr=bData.content;
        }
        return {sha:data.sha,catalog:JSON.parse(decodeURIComponent(escape(atob(contentStr.replace(/\n/g,'')))))};
      },
      write:(merged,sha)=>{if(catalogContext(cfg)!==operationContext)throw new Error('La configuración cambió. No se escribió el catálogo.');return ghApi('PUT',{body:JSON.stringify({message:'Actualizar catálogo desde el panel HourTV',
        branch:operationConfig.branch,content:btoa(unescape(encodeURIComponent(JSON.stringify(merged,null,2)))),...(sha?{sha}:{})})},operationConfig);}
    });
    notifyCatalogEvent('hourtv:github-operation',{context:operationContext,state:'success'});
    if(catalogContext(cfg)!==operationContext){toast('Publicado en el repositorio anterior. Se conservaron los datos locales actuales.','warn');return true;}
    const persistence=persistCatalogBase(outcome.catalog,operationContext);
    const expectedGeneration=catalogBaseGeneration;
    await persistence;
    if(catalogContext(cfg)!==operationContext||catalogBaseGeneration!==expectedGeneration||catalogBaseContext!==operationContext){toast('Publicado en GitHub. El contexto local cambió durante el guardado; se conservaron los datos actuales sin sincronizaciones adicionales.','warn');return true;}
    catalog=CatalogSync.merge(pending,catalog,outcome.catalog);
    for(const id of deleting)deletedIds.delete(id);
    saveDeletedIds();await save();render();
    toast('¡Publicado! Se conservaron los cambios remotos y tus servidores.','ok');
    await syncCatalogSnapshotToSupabase(JSON.stringify(catalogBase));
    if(!options.skipReplacementFinalize&&typeof finalizePendingReplacementPublish==='function')await finalizePendingReplacementPublish(true);
    return true;
  }catch(e){notifyCatalogEvent('hourtv:github-operation',{context:operationContext,state:'error',message:e.message});toast('Error: '+e.message,'err');if(!options.skipReplacementFinalize&&typeof finalizePendingReplacementPublish==='function')await finalizePendingReplacementPublish(false,e.message);if(options.throwOnError)throw e;return false}
  finally{publishing=false}
}
