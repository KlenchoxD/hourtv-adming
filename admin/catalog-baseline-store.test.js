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

test('restores the newer large catalog instead of stale localStorage',()=>{
  const {makeCatalogSnapshot,selectCatalogSnapshot}=require('./catalog-baseline-store');
  const old={movies:[],series:Array.from({length:72},(_,id)=>({id})),sources:[]};
  const current={...old,series:Array.from({length:320},(_,id)=>({id}))};
  assert.deepEqual(selectCatalogSnapshot(old,current,'repo'),current);
  assert.deepEqual(selectCatalogSnapshot(makeCatalogSnapshot(old,'repo',10),makeCatalogSnapshot(current,'repo',20),'repo'),current);
});

test('does not prefer a larger cache over newer local edits',()=>{
  const {makeCatalogSnapshot,selectCatalogSnapshot}=require('./catalog-baseline-store');
  const local={movies:[],series:[{id:'edited'}],sources:[]};
  const cached={movies:[],series:[{id:'old'},{id:'old2'}],sources:[]};
  assert.deepEqual(selectCatalogSnapshot(makeCatalogSnapshot(local,'repo',30),makeCatalogSnapshot(cached,'repo',20),'repo'),local);
});

test('ignores another repository cache and invalid snapshots',()=>{
  const {makeCatalogSnapshot,selectCatalogSnapshot}=require('./catalog-baseline-store');
  const value={movies:[],series:[{id:'keep'}],sources:[]};
  assert.deepEqual(selectCatalogSnapshot(value,makeCatalogSnapshot(value,'other',50),'repo'),value);
  assert.equal(selectCatalogSnapshot({broken:true},{cacheVersion:2,catalog:{series:'invalid'}},'repo'),null);
});

test('creates detached snapshots and preserves valid empty catalogs',()=>{
  const {makeCatalogSnapshot,selectCatalogSnapshot}=require('./catalog-baseline-store');
  const value={movies:[],series:[],sources:[]};
  const snapshot=makeCatalogSnapshot(value,'repo',12);
  value.series.push({id:'later'});
  assert.equal(snapshot.catalog.series.length,0);
  assert.deepEqual(selectCatalogSnapshot(null,snapshot,'repo'),{movies:[],series:[],sources:[]});
});
