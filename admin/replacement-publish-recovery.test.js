'use strict';
const test=require('node:test');const assert=require('node:assert/strict');
const {saveRecovery,loadRecovery,retryRecovery}=require('./replacement-publish-recovery');
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
