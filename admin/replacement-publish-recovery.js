(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.HourTVPublishRecovery=api;}(typeof globalThis!=='undefined'?globalThis:this,function(){
'use strict';
const KEY='hourtv_replacement_recovery';
function saveRecovery(storage,state){
 const clean={phase:state.phase,candidateIds:[...new Set(state.candidateIds||[])],updatedAt:new Date().toISOString(),error:state.error||null};
 storage.setItem(KEY,JSON.stringify(clean));
 storage.removeItem('hourtv_replacements_pending_publish');storage.removeItem('hourtv_replacements_pending_finalize');
 storage.setItem(clean.phase==='pending_publish'?'hourtv_replacements_pending_publish':'hourtv_replacements_pending_finalize','true');return clean;
}
function loadRecovery(storage){try{const value=JSON.parse(storage.getItem(KEY)||'null');return value&&['pending_publish','pending_finalize'].includes(value.phase)&&Array.isArray(value.candidateIds)?value:null}catch(_){return null}}
function clearRecovery(storage){storage.removeItem(KEY);storage.removeItem('hourtv_replacements_pending_publish');storage.removeItem('hourtv_replacements_pending_finalize');}
async function retryRecovery({storage,publish,callRpc}){
 const state=loadRecovery(storage);if(!state)return {phase:'none'};
 if(state.phase==='pending_publish'){
  try{await publish();}catch(error){saveRecovery(storage,{...state,phase:'pending_publish',error:error.message});return {phase:'pending_publish',error};}
  saveRecovery(storage,{...state,phase:'pending_finalize',error:null});
 }
 try{await callRpc('admin_finalize_replacement_publish',{p_candidate_ids:state.candidateIds,p_succeeded:true,p_error:null});}
 catch(error){saveRecovery(storage,{...state,phase:'pending_finalize',error:error.message});return {phase:'pending_finalize',published:state.phase==='pending_publish',error};}
 clearRecovery(storage);return {phase:'complete',published:state.phase==='pending_publish'};
}
return {KEY,saveRecovery,loadRecovery,clearRecovery,retryRecovery};
}));
