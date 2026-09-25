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
