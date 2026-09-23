'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { AdapterRegistry } = require('./backup-adapters');
const { searchReplacement, testProviderConfiguration, revalidateCandidate, revalidateStaleBatch, applyConfirmedReplacement, discardAtomically, executeBatchWorkflow, selectOptimalCandidate, loadAdminData } = require('./replacement-admin-actions');

const target = { sourceId:'s1', type:'movie', tmdbId:7, title:'Peli', language:'es', year:2025 };
const fresh = { type:'movie', tmdbId:7, title:'Peli', language:'es', year:2025, reproducible:true, url:'https://media.example/video.m3u8', checkedAt:'2026-09-22T01:00:00Z', expiresAt:'2026-09-23T01:00:00Z' };

test('search executes active adapters by priority and persists attempts, best fresh candidate and notification', async () => {
  const registry = new AdapterRegistry();
  registry.register('a', { searchMovie:async()=>[{...fresh, checkedAt:'2026-09-22T00:10:00Z'}, {...fresh, url:'https://media.example/new.m3u8', checkedAt:'2026-09-22T01:10:00Z'}], searchEpisode:async()=>[] });
  const calls=[];
  const result = await searchReplacement({ source:target, providers:[{id:'p2',adapterName:'none',priority:2},{id:'p1',adapterName:'a',priority:1,isActive:true}], registry, now:new Date('2026-09-22T02:00:00Z'), api:{
    persistAttempts:async a=>calls.push(['attempts',a]), persistCandidate:async c=>(calls.push(['candidate',c]),{...c,id:'c1'}), createNotification:async n=>calls.push(['notice',n]), incrementProviderSuccess:async id=>calls.push(['success',id])
  }});
  assert.equal(result.candidate.url,'https://media.example/new.m3u8');
  assert.deepEqual(calls.map(c=>c[0]),['attempts','candidate','success','notice']);
  assert.match(calls.find(c=>c[0]==='notice')[1].message, /prioridad 1.*confianza alta 100\/100/i);
});

test('search explains that a backup page cannot be selected without its adapter', async () => {
  const calls = [];
  const result = await searchReplacement({
    source: target,
    providers: [{ id: 'p1', name: 'Página A', adapterName: 'missing', priority: 1, isActive: true }],
    registry: new AdapterRegistry(),
    api: { persistAttempts: async attempts => calls.push(['attempts', attempts]), createNotification: async notice => calls.push(['notice', notice]) },
  });
  assert.equal(result.candidate, null);
  assert.equal(result.reason, 'no_registered_adapter');
  assert.match(result.message, /adaptador instalado/i);
  assert.equal(calls[0][1][0].reason, 'adapter_not_registered');
});

test('direct admin load always includes providers',async()=>{
  const calls=[];const client={from:table=>({select(){calls.push(table);return this},order(){return Promise.resolve({data:[{table}],error:null})}})};
  const data=await loadAdminData(client);assert.ok(calls.includes('backup_providers'));assert.equal(data.providers[0].table,'backup_providers');
});

test('optimal candidate uses provider priority then freshest check',()=>{
  const providers=[{id:'slow',priority:9},{id:'first',priority:1}];
  const chosen=selectOptimalCandidate([{id:'x',backup_provider_id:'slow',confidence:'high',status:'pending',checked_at:'2026-09-22T03:00:00Z'},{id:'old',backup_provider_id:'first',confidence:'high',status:'pending',checked_at:'2026-09-22T01:00:00Z'},{id:'new',backup_provider_id:'first',confidence:'high',status:'pending',checked_at:'2026-09-22T02:00:00Z'}],providers);
  assert.equal(chosen.id,'new');
});

test('provider test calls adapter testConfiguration and persists real result', async () => {
  const registry = new AdapterRegistry().register('a',{searchMovie:async()=>[],searchEpisode:async()=>[],testConfiguration:async p=>({ok:true,detail:p.baseUrl})});
  let saved;
  const result=await testProviderConfiguration({provider:{id:'p1',adapterName:'a',baseUrl:'https://safe.example'},registry,now:new Date('2026-09-22'),save:async patch=>{saved=patch;}});
  assert.equal(result.ok,true); assert.equal(saved.lastError,null); assert.equal(saved.successfulSearches,1);
});

test('provider test rejects private or credentialed base URLs before adapter I/O',async()=>{
  let called=0,saved;const registry=new AdapterRegistry().register('a',{searchMovie:async()=>[],searchEpisode:async()=>[],testConfiguration:async()=>{called++;return {ok:true}}});
  const result=await testProviderConfiguration({provider:{adapterName:'a',baseUrl:'https://user:pass@127.0.0.1/x'},registry,save:async patch=>{saved=patch;}});
  assert.equal(result.ok,false);assert.equal(called,0);assert.match(saved.lastError,/segura/i);
});

test('stale candidate is revalidated through adapter evidence', async () => {
  const registry = new AdapterRegistry().register('a',{searchMovie:async()=>[],searchEpisode:async()=>[],validateCandidate:async()=>({...fresh,checkedAt:'2026-09-22T02:00:00Z',expiresAt:'2026-09-23T02:00:00Z'})});
  const result=await revalidateCandidate({candidate:{...fresh,providerAdapterName:'a',checkedAt:'2020-01-01',expiresAt:'2020-01-02'},target,registry,now:new Date('2026-09-22T03:00:00Z')});
  assert.equal(result.confidence,'high');
});

test('batch attempts stale revalidation and excludes only candidates without evidence',async()=>{
  const registry=new AdapterRegistry().register('a',{searchMovie:async()=>[],searchEpisode:async()=>[],validateCandidate:async c=>c.id==='ok'?{...fresh,checkedAt:'2026-09-22T02:00:00Z',expiresAt:'2026-09-23T02:00:00Z'}:null});
  const result=await revalidateStaleBatch({candidates:[{...fresh,id:'ok',expiresAt:'2020-01-01'},{...fresh,id:'bad',expiresAt:'2020-01-01'}],targetFor:()=>target,providerForCandidate:()=>({adapterName:'a'}),registry,now:new Date('2026-09-22T03:00:00Z')});
  assert.equal(result.eligible.length,1);assert.equal(result.excluded.length,1);
});

test('individual rejects missing high confidence, unsafe URL, or declined confirmation before RPC', async () => {
  let rpc=0; const callRpc=async()=>{rpc++;};
  await assert.rejects(applyConfirmedReplacement({candidate:{...fresh,confidence:'medium'},confirm:()=>true,callRpc}),/confianza alta/i);
  await assert.rejects(applyConfirmedReplacement({candidate:{...fresh,confidence:'high',url:'http://127.0.0.1/x'},confirm:()=>true,callRpc}),/URL segura/i);
  const declined=await applyConfirmedReplacement({candidate:{...fresh,confidence:'high'},confirm:()=>false,callRpc});
  assert.equal(declined.cancelled,true); assert.equal(rpc,0);
});

test('apply and discard use one atomic RPC each', async () => {
  const calls=[]; const callRpc=async(name,args)=>(calls.push([name,args]),{ok:true});
  await applyConfirmedReplacement({candidate:{...fresh,id:'c1',confidence:'high'},notificationId:'n1',confirm:()=>true,callRpc});
  await discardAtomically({candidateId:'c1',notificationId:'n1',callRpc});
  assert.deepEqual(calls.map(c=>c[0]),['admin_apply_replacement','admin_discard_replacement']);
});

test('batch applies atomically, publishes once and finalizes success',async()=>{
  const calls=[];let publishes=0;const callRpc=async(name,args)=>(calls.push([name,args]),{ok:true});
  let localReady=false;
  const result=await executeBatchWorkflow({candidateIds:['a','b'],callRpc,afterApply:async()=>{localReady=true;},publish:async()=>{assert.equal(localReady,true);publishes++;}});
  assert.equal(result.published,true);assert.equal(publishes,1);
  assert.deepEqual(calls.map(c=>c[0]),['admin_apply_replacement_batch','admin_finalize_replacement_publish']);
  assert.equal(calls[1][1].p_succeeded,true);
});

test('batch DB failure never publishes; publish failure finalizes pending state once',async()=>{
  let publishes=0;
  await assert.rejects(executeBatchWorkflow({candidateIds:['a'],callRpc:async()=>{throw new Error('db')},publish:async()=>{publishes++;}}),/db/);
  assert.equal(publishes,0);
  const calls=[];const result=await executeBatchWorkflow({candidateIds:['a'],callRpc:async(name,args)=>(calls.push([name,args]),{}),publish:async()=>{publishes++;throw new Error('github')}});
  assert.equal(result.published,false);assert.equal(publishes,1);assert.equal(calls[1][1].p_succeeded,false);
});

test('published but finalize failure returns pending_finalize instead of false rollback',async()=>{
  let step=0;const result=await executeBatchWorkflow({candidateIds:['a'],callRpc:async name=>{step++;if(name==='admin_finalize_replacement_publish')throw new Error('finalize')},publish:async()=>{step++;}});
  assert.equal(result.phase,'pending_finalize');assert.equal(result.published,true);assert.equal(step,3);
});
