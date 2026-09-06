let catalogBase;
try{catalogBase=JSON.parse(localStorage.getItem('hourtv_admin_base')||'null')||undefined}catch(e){}
const publishCatalogSafely=CatalogSync.createPublisher();
let publishing=false;
async function publish(){
  if(!cfg.token){toast('Configura GitHub primero','err');openConfig();return}
  if(publishing){toast('Ya hay una publicación en curso.','warn');return}
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
  }catch(e){toast('Error: '+e.message,'err')}
  finally{publishing=false}
}
