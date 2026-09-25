const {test}=require('node:test');
const assert=require('node:assert/strict');
const {createCatalogBaselineStore}=require('./catalog-baseline-store');

function fakeIndexedDB(){
  const records=new Map();
  let initialized=false;
  return {
    records,
    open(){
      const request={};
      queueMicrotask(()=>{
        const db={
          objectStoreNames:{contains:name=>initialized&&name==='snapshots'},
          createObjectStore(){initialized=true},
          close(){},
          transaction(){
            const tx={
              objectStore(){return {
                get:key=>schedule(()=>records.get(key)),
                put:(value,key)=>schedule(()=>{records.set(key,value);return key})
              }}
            };
            function schedule(action){
              const operation={};
              queueMicrotask(()=>{
                operation.result=action();
                operation.onsuccess&&operation.onsuccess();
                queueMicrotask(()=>tx.oncomplete&&tx.oncomplete());
              });
              return operation;
            }
            return tx;
          }
        };
        request.result=db;
        if(!initialized)request.onupgradeneeded&&request.onupgradeneeded();
        request.onsuccess&&request.onsuccess();
      });
      return request;
    }
  };
}

test('stores and restores a large catalog baseline outside localStorage',async()=>{
  const indexedDB=fakeIndexedDB();
  const store=createCatalogBaselineStore(indexedDB);
  const baseline={movies:Array.from({length:4000},(_,id)=>({id,title:`Movie ${id}`})),series:[]};
  await store.set(baseline);
  assert.deepEqual(await store.get(),baseline);
  assert.equal(indexedDB.records.size,1);
});

test('reports IndexedDB unavailable without corrupting caller state',async()=>{
  const store=createCatalogBaselineStore(null);
  await assert.rejects(store.get(),/IndexedDB no está disponible/);
  await assert.rejects(store.set({movies:[]}),/IndexedDB no está disponible/);
});
