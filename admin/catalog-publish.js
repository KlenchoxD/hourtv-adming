let catalogBase;
try{catalogBase=JSON.parse(localStorage.getItem('hourtv_admin_base')||'null')||undefined}catch(e){}
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
  const pending=JSON.parse(JSON.stringify(catalog));
  const deleting=new Set(deletedIds);
  try{
    const outcome=await publishCatalogSafely({base:catalogBase,local:pending,deleted:deleting,
      read:async()=>{
        const res=await ghApi('GET');
        if(res.status===404)return {catalog:{},sha:undefined};
        if(!res.ok)throw new Error('No se pudo leer el catálogo actual ('+res.status+'). No se sobrescribió.');
        const data=await res.json();
        if(!data.sha)throw new Error('Respuesta de catálogo incompleta.');
        let contentStr;
        if(typeof data.content==='string'&&data.content.length>0){
          contentStr=data.content;
        }else{
          const bRes=await fetch(`https://api.github.com/repos/${cfg.owner}/${cfg.repo}/git/blobs/${data.sha}`,{
            headers:{Authorization:`Bearer ${cfg.token}`,Accept:'application/vnd.github+json'}
          });
          if(!bRes.ok)throw new Error('Error al leer catálogo extenso ('+bRes.status+').');
          const bData=await bRes.json();
          contentStr=bData.content;
        }
        return {sha:data.sha,catalog:JSON.parse(decodeURIComponent(escape(atob(contentStr.replace(/\n/g,'')))))};
      },
      write:(merged,sha)=>ghApi('PUT',{body:JSON.stringify({message:'Actualizar catálogo desde el panel HourTV',
        branch:cfg.branch,content:btoa(unescape(encodeURIComponent(JSON.stringify(merged,null,2)))),...(sha?{sha}:{})})})
    });
    catalogBase=outcome.catalog;
    catalog=CatalogSync.merge(pending,catalog,outcome.catalog);
    localStorage.setItem('hourtv_admin_base',JSON.stringify(catalogBase));
    for(const id of deleting)deletedIds.delete(id);
    saveDeletedIds();save();render();
    toast('¡Publicado! Se conservaron los cambios remotos y tus servidores.','ok');
    await syncCatalogSnapshotToSupabase(JSON.stringify(catalogBase));
    if(!options.skipReplacementFinalize&&typeof finalizePendingReplacementPublish==='function')await finalizePendingReplacementPublish(true);
    return true;
  }catch(e){toast('Error: '+e.message,'err');if(!options.skipReplacementFinalize&&typeof finalizePendingReplacementPublish==='function')await finalizePendingReplacementPublish(false,e.message);if(options.throwOnError)throw e;return false}
  finally{publishing=false}
}
