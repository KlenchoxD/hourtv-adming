(function(root){
  'use strict';
  const same=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
  const copy=x=>x===undefined?undefined:JSON.parse(JSON.stringify(x));
  function key(x){
    if(!x||typeof x!=='object')return JSON.stringify(x);
    if(x.id!=null)return 'id:'+x.id;
    if(x.number!=null)return 'number:'+x.number;
    if(x.url)return JSON.stringify([x.url,x.language||'',x.name||'']);
    return JSON.stringify(x);
  }
  function merge(base,local,remote){
    if(same(local,base))return copy(remote);
    if(same(remote,base)||same(local,remote))return copy(local);
    if(local===undefined)return undefined;
    if(remote===undefined)return copy(local);
    if(Array.isArray(local)&&Array.isArray(remote)){
      const b=new Map((Array.isArray(base)?base:[]).map(x=>[key(x),x]));
      const l=new Map(local.map(x=>[key(x),x]));
      const r=new Map(remote.map(x=>[key(x),x]));
      return [...new Set([...r.keys(),...l.keys()])].map(k=>merge(b.get(k),l.get(k),r.get(k))).filter(x=>x!==undefined);
    }
    if(local&&remote&&typeof local==='object'&&typeof remote==='object'&&!Array.isArray(local)&&!Array.isArray(remote)){
      const out={};
      for(const k of new Set([...Object.keys(remote),...Object.keys(local)])){
        const value=merge(base&&base[k],local[k],remote[k]);
        if(value!==undefined)out[k]=value;
      }
      return out;
    }
    return copy(local);
  }
  function createPublisher(){
    let active=null;
    return function publish(options){
      if(active)return active;
      active=(async()=>{
        for(let attempt=0;attempt<3;attempt++){
          const snapshot=await options.read();
          const merged=merge(options.base,options.local,snapshot.catalog);
          for(const name of ['movies','series','sources','liveChannels']){
            if(Array.isArray(merged[name]))merged[name]=merged[name].filter(x=>!options.deleted.has(x.id));
          }
          const response=await options.write(merged,snapshot.sha);
          if(response.ok)return {catalog:merged,response};
          if(response.status!==409&&response.status!==422){
            const error=await response.json().catch(()=>({}));
            throw new Error(error.message||'No se pudo publicar ('+response.status+').');
          }
        }
        throw new Error('El catálogo sigue cambiando. Tus cambios siguen guardados localmente; vuelve a publicar cuando termine la otra subida.');
      })().finally(()=>{active=null;});
      return active;
    };
  }
  const api={merge,createPublisher};
  if(typeof module!=='undefined')module.exports=api;
  root.CatalogSync=api;
})(typeof window!=='undefined'?window:globalThis);
