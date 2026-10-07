const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const CatalogSync=require('./catalog-sync');

test('successful GitHub publish is not reported as failed by a full localStorage',async()=>{
  const remote={version:2,movies:[{id:'movie-1',title:'Published'}],series:[],sources:[],liveChannels:[]};
  let savedBaseline;
  const toasts=[];
  const storage={
    getItem:()=>null,
    removeItem:()=>{},
    setItem(){throw new Error('QuotaExceededError')}
  };
  const context={
    window:{HourTvCatalogBaselineStore:{get:async()=>remote,set:async value=>{savedBaseline=value}}},
    localStorage:storage,
    CatalogSync,
    cfg:{token:'test',owner:'owner',repo:'catalog',branch:'main',path:'catalog.json'},
    catalog:remote,
    deletedIds:new Set(),
    supabase:{},
    sbSession:null,
    toast:(message,type)=>toasts.push({message,type}),
    openConfig(){},
    saveDeletedIds(){},
    save(){},
    render(){},
    console,
    atob,
    btoa,
    escape,
    unescape,
    encodeURIComponent,
    ghApi:async method=>method==='GET'?{
      status:200,
      ok:true,
      json:async()=>({sha:'sha-1',content:btoa(unescape(encodeURIComponent(JSON.stringify(remote))))})
    }:{ok:true,status:200}
  };
  vm.runInNewContext(fs.readFileSync(require.resolve('./catalog-publish.js'),'utf8'),context);

  assert.equal(await context.publish(),true);
  assert.deepEqual(savedBaseline,remote);
  assert.ok(toasts.some(item=>item.message.includes('¡Publicado!')));
  assert.ok(!toasts.some(item=>item.type==='err'));
});
test('late baseline restoration cannot overwrite newly persisted comparison base',async()=>{
  let resolveRestore;const restored=new Promise(resolve=>resolveRestore=resolve);
  const old={movies:[{id:'old'}]},fresh={movies:[{id:'new'}]};
  const context={window:{HourTvCatalogBaselineStore:{get:()=>restored,set:async()=>{}}},cfg:{owner:'owner',repo:'repo'},localStorage:{getItem:()=>null,removeItem(){},setItem(){}},CatalogSync,console,save(){}};
  vm.createContext(context);vm.runInContext(fs.readFileSync(require.resolve('./catalog-publish.js'),'utf8'),context);
  await context.persistCatalogBase(fresh);resolveRestore(old);
  await vm.runInContext('catalogBaseReady',context);
  assert.deepEqual(vm.runInContext('catalogBase',context),fresh);
});
for(const change of ['repository','generation'])test(`publish does not apply stale outcome after persistence changes ${change}`,async()=>{
  const remote={version:2,movies:[{id:'a',title:'Repository A'}],series:[],sources:[]};
  const current={version:2,movies:[{id:'b',title:'Current local'}],series:[],sources:[]};
  let release,start;const started=new Promise(r=>start=r);let finalized=0,snapshots=0,saved=0;
  const context={window:{HourTvCatalogBaselineStore:{get:async()=>null,set:async()=>{start();await new Promise(r=>release=r)}}},localStorage:{getItem:()=>null,removeItem(){},setItem(){}},CatalogSync,
    cfg:{token:'synthetic',owner:'owner',repo:'a',branch:'main'},catalog:remote,deletedIds:new Set(['keep']),supabase:{},sbSession:null,toast(){},openConfig(){},saveDeletedIds(){saved++},save(){},render(){},console,atob,btoa,escape,unescape,encodeURIComponent,
    finalizePendingReplacementPublish:async()=>finalized++,ghApi:async method=>method==='GET'?{ok:true,status:200,json:async()=>({sha:'a',content:btoa(JSON.stringify(remote))})}:{ok:true,status:200}};
  vm.createContext(context);vm.runInContext(fs.readFileSync(require.resolve('./catalog-publish.js'),'utf8'),context);
  context.syncCatalogSnapshotToSupabase=async()=>snapshots++;
  const pending=context.publish({throwOnError:true});await started;
  context.catalog=current;
  if(change==='repository')context.cfg.repo='b';else vm.runInContext('catalogBaseGeneration++',context);
  release();assert.equal(await pending,true);
  assert.deepEqual(context.catalog,current);assert.equal(context.deletedIds.has('keep'),true);
  assert.equal(saved,0);assert.equal(finalized,0);assert.equal(snapshots,0);
});
