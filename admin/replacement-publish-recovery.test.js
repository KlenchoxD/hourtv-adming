'use strict';
const test=require('node:test');const assert=require('node:assert/strict');
const {saveRecovery,loadRecovery,retryRecovery,beginIndividualRecovery,hasPendingRecovery}=require('./replacement-publish-recovery');
const {applyConfirmedReplacement}=require('./replacement-admin-actions');
function storage(){const m=new Map();return {getItem:k=>m.get(k)||null,setItem:(k,v)=>m.set(k,v),removeItem:k=>m.delete(k),has:k=>m.has(k)};}
test('pending_publish survives reload, publishes once, finalizes and clears flags',async()=>{
 const s=storage();saveRecovery(s,{phase:'pending_publish',candidateIds:['a','b']});assert.equal(loadRecovery(s).phase,'pending_publish');
 let pubs=0;const rpc=[];const result=await retryRecovery({storage:s,publish:async()=>{pubs++},callRpc:async(n,a)=>rpc.push([n,a])});
 assert.equal(result.phase,'complete');assert.equal(pubs,1);assert.equal(rpc.length,1);assert.equal(loadRecovery(s),null);assert.equal(s.has('hourtv_replacements_pending_publish'),false);
});
test('pending_finalize after reload calls only finalize and clears all state',async()=>{
 const s=storage();saveRecovery(s,{phase:'pending_finalize',candidateIds:['a']});let pubs=0,rpcs=0;
 await retryRecovery({storage:s,publish:async()=>{pubs++},callRpc:async()=>{rpcs++}});
 assert.equal(pubs,0);assert.equal(rpcs,1);assert.equal(loadRecovery(s),null);assert.equal(s.has('hourtv_replacements_pending_finalize'),false);
});
test('publish success plus finalize failure transitions to pending_finalize and never republishes',async()=>{
 const s=storage();saveRecovery(s,{phase:'pending_publish',candidateIds:['a']});let pubs=0,rpcs=0;
 const first=await retryRecovery({storage:s,publish:async()=>{pubs++},callRpc:async()=>{rpcs++;throw new Error('db')}});
 assert.equal(first.phase,'pending_finalize');assert.equal(loadRecovery(s).phase,'pending_finalize');
 await retryRecovery({storage:s,publish:async()=>{pubs++},callRpc:async()=>{rpcs++}});
 assert.equal(pubs,1);assert.equal(rpcs,2);assert.equal(loadRecovery(s),null);
});
test('failed publish stays pending_publish and does not finalize',async()=>{
 const s=storage();saveRecovery(s,{phase:'pending_publish',candidateIds:['a']});let rpcs=0;
 const result=await retryRecovery({storage:s,publish:async()=>{throw new Error('github')},callRpc:async()=>{rpcs++}});
 assert.equal(result.phase,'pending_publish');assert.equal(rpcs,0);assert.equal(loadRecovery(s).phase,'pending_publish');
});
test('individual apply persists IDs, survives reload, failed then successful publish finalizes once',async()=>{
 const s=storage();let apply=0,publish=0,finalize=0;const candidate={id:'candidate-1',confidence:'high',url:'https://media.example/v.m3u8',expiresAt:'2099-01-01'};
 await applyConfirmedReplacement({candidate,notificationId:'n1',confirm:()=>true,callRpc:async()=>{apply++;}});beginIndividualRecovery(s,candidate.id);assert.equal(loadRecovery(s).candidateIds[0],'candidate-1');
 await retryRecovery({storage:s,publish:async()=>{publish++;throw new Error('offline')},callRpc:async()=>{finalize++}});
 assert.equal(loadRecovery(s).phase,'pending_publish');
 await retryRecovery({storage:s,publish:async()=>{publish++},callRpc:async()=>{finalize++}});
 assert.equal(apply,1);assert.equal(publish,2);assert.equal(finalize,1);assert.equal(loadRecovery(s),null);
});
test('a second operation is blocked and cannot overwrite pending IDs',()=>{
 const s=storage();beginIndividualRecovery(s,'first');assert.equal(hasPendingRecovery(s),true);
 assert.throws(()=>beginIndividualRecovery(s,'second'),/pendiente/i);assert.deepEqual(loadRecovery(s).candidateIds,['first']);
});
