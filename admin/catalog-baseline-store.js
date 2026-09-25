(function(root){
  'use strict';

  const DB_NAME='hourtv-admin-cache';
  const STORE_NAME='snapshots';
  const BASELINE_KEY='catalog-baseline-v1';

  function createCatalogBaselineStore(indexedDBApi){
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
          const operation=method==='put'?store.put(value,BASELINE_KEY):store.get(BASELINE_KEY);
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

  const api={createCatalogBaselineStore,...createCatalogBaselineStore()};
  if(typeof module!=='undefined'&&module.exports)module.exports=api;
  root.HourTvCatalogBaselineStore=api;
})(typeof window!=='undefined'?window:globalThis);
