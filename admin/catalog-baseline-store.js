(function(root){
  'use strict';

  const DB_NAME='hourtv-admin-cache';
  const STORE_NAME='snapshots';
  const BASELINE_KEY='catalog-baseline-v1';
  const CATALOG_KEY='catalog-current-v1';

  function validCatalog(value){
    return value&&typeof value==='object'&&!Array.isArray(value)
      &&['movies','series','sources'].some(key=>Array.isArray(value[key]))
      &&['movies','series','sources'].every(key=>value[key]===undefined||Array.isArray(value[key]));
  }

  function makeCatalogSnapshot(value,context,savedAt=Date.now()){
    return {cacheVersion:2,context,savedAt,catalog:JSON.parse(JSON.stringify(value))};
  }

  function selectCatalogSnapshot(local,indexed,context){
    function candidate(value){
      const wrapped=value&&value.cacheVersion===2;
      const catalog=wrapped?value.catalog:value;
      if(!validCatalog(catalog)||wrapped&&value.context!==context)return null;
      return {catalog,savedAt:wrapped&&Number.isFinite(value.savedAt)?value.savedAt:0};
    }
    const a=candidate(local),b=candidate(indexed);
    // Legacy IndexedDB was the large-catalog fallback. On equal unknown ages,
    // prefer it over the localStorage value left behind by a quota failure.
    return b&&(!a||b.savedAt>=a.savedAt)?b.catalog:a?a.catalog:null;
  }

  function createCatalogBaselineStore(indexedDBApi,key=BASELINE_KEY){
    const api=indexedDBApi===undefined?root.indexedDB:indexedDBApi;

    function open(){
      if(!api)return Promise.reject(new Error('IndexedDB no está disponible.'));
      return new Promise((resolve,reject)=>{
        let request;
        try{request=api.open(DB_NAME,1)}catch(error){reject(error);return}
        request.onupgradeneeded=()=>{
          const db=request.result;
          if(!db.objectStoreNames.contains(STORE_NAME))db.createObjectStore(STORE_NAME);
        };
        request.onsuccess=()=>resolve(request.result);
        request.onerror=()=>reject(request.error||new Error('No se pudo abrir IndexedDB.'));
        request.onblocked=()=>reject(new Error('La base de caché está bloqueada por otra pestaña.'));
      });
    }

    async function request(method,value){
      const db=await open();
      return new Promise((resolve,reject)=>{
        let settled=false;
        const fail=error=>{if(settled)return;settled=true;db.close();reject(error)};
        try{
          const tx=db.transaction(STORE_NAME,method==='put'?'readwrite':'readonly');
          const store=tx.objectStore(STORE_NAME);
          const operation=method==='put'?store.put(value,key):store.get(key);
          let result;
          operation.onsuccess=()=>{result=operation.result};
          operation.onerror=()=>fail(operation.error||new Error('Falló la operación de caché.'));
          tx.oncomplete=()=>{if(settled)return;settled=true;db.close();resolve(result)};
          tx.onerror=()=>fail(tx.error||new Error('Falló la transacción de caché.'));
          tx.onabort=()=>fail(tx.error||new Error('Se canceló la transacción de caché.'));
        }catch(error){fail(error)}
      });
    }

    return {get:()=>request('get'),set:value=>request('put',value)};
  }

  const baseline=createCatalogBaselineStore();
  const current=createCatalogBaselineStore(undefined,CATALOG_KEY);
  const api={
    createCatalogBaselineStore,
    makeCatalogSnapshot,
    selectCatalogSnapshot,
    ...baseline,
    getCatalog:current.get,
    setCatalog:current.set,
  };
  if(typeof module!=='undefined'&&module.exports)module.exports=api;
  root.HourTvCatalogBaselineStore=api;
})(typeof window!=='undefined'?window:globalThis);
