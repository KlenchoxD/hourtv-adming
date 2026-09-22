(function(root,factory){
  const logic=typeof module==='object'&&module.exports?require('./replacement-logic'):root.HourTVReplacementLogic;
  const adapters=typeof module==='object'&&module.exports?require('./backup-adapters'):root.HourTVBackupAdapterCore;
  const api=factory(logic,adapters);
  if(typeof module==='object'&&module.exports)module.exports=api;else root.HourTVReplacementActions=api;
}(typeof globalThis!=='undefined'?globalThis:this,function(logic,adapters){
  'use strict';
  const providerAdapter=p=>p.adapterName||p.adapter_name;
  const providerActive=p=>p.isActive!==undefined?p.isActive:p.is_active;
  const providerFor=(providers,id)=>providers.find(p=>p.id===id);
  const escapeHtml=value=>String(value??'').replace(/[&<>\"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot;'}[c]));

  async function searchReplacement({source,providers,registry,api,now=new Date(),maxAgeMs}){
    const normalized=providers.map(p=>({...p,adapterName:providerAdapter(p),isActive:providerActive(p)}));
    const result=await adapters.searchWithFallback({providers:normalized,registry,kind:source.type==='episode'?'episode':'movie',query:source,now,maxAgeMs});
    if(api.persistSearchResult){
      const providerId=(result.attempts.find(a=>a.reason==='high_candidate_found')||{}).providerId||null;
      return api.persistSearchResult({source,result,providerId});
    }
    await api.persistAttempts(result.attempts);
    if(!result.candidate){
      await api.createNotification({notificationType:'replacement_unavailable',sourceId:source.sourceId,message:'No se encontró un reemplazo de confianza alta.'});
      return result;
    }
    const winningAttempt=result.attempts.find(a=>a.reason==='high_candidate_found');
    const provider=providerFor(normalized,winningAttempt.providerId);
    const saved=await api.persistCandidate({...result.candidate,sourceId:source.sourceId,backupProviderId:provider.id});
    await api.incrementProviderSuccess(provider.id);
    await api.createNotification({notificationType:'replacement_found',sourceId:source.sourceId,candidateId:saved.id,message:`Se encontró un reemplazo de confianza alta en ${provider.name}.`});
    return {...result,candidate:saved};
  }

  async function testProviderConfiguration({provider,registry,save,now=new Date()}){
    if((provider.baseUrl||provider.base_url)&&!logic.isValidHttpsUrl(provider.baseUrl||provider.base_url)){
      const error='La URL base no es HTTPS pública y segura';await save({lastTestedAt:now.toISOString(),lastError:error});return {ok:false,error};
    }
    const adapter=registry.get(providerAdapter(provider));
    if(!adapter||typeof adapter.testConfiguration!=='function'){
      const error='El adaptador no implementa una prueba segura de configuración';
      await save({lastTestedAt:now.toISOString(),lastError:error}); return {ok:false,error};
    }
    try{
      const result=await adapter.testConfiguration(provider);
      if(!result||result.ok!==true)throw new Error(result&&result.error||'La prueba no confirmó el proveedor');
      await save({lastTestedAt:now.toISOString(),lastError:null,successfulSearches:Number(provider.successfulSearches||provider.successful_searches||0)+1});
      return result;
    }catch(error){await save({lastTestedAt:now.toISOString(),lastError:error.message});return {ok:false,error:error.message};}
  }

  async function revalidateCandidate({candidate,target,provider,registry,now=new Date(),maxAgeMs}){
    const name=candidate.providerAdapterName||providerAdapter(provider||{});
    const adapter=registry.get(name);
    if(!adapter||typeof adapter.validateCandidate!=='function')return { ...candidate, confidence:'rejected', eligibleForBatch:false, revalidationReason:'adapter_cannot_revalidate' };
    try{
      const evidence=await adapter.validateCandidate(candidate,provider);
      const evaluated=logic.evaluateCandidate(target,evidence,{now,maxAgeMs});
      return {...candidate,...evidence,...evaluated};
    }catch(error){return {...candidate,confidence:'rejected',eligibleForBatch:false,revalidationReason:error.message};}
  }

  async function applyConfirmedReplacement({candidate,notificationId,confirm,callRpc,now=new Date()}){
    if(candidate.confidence!=='high')throw new Error('Solo se admite confianza alta');
    if(!logic.isValidHttpsUrl(candidate.url||candidate.proposed_url))throw new Error('El candidato no tiene una URL segura HTTPS pública');
    if(!Number.isFinite(Date.parse(candidate.expiresAt||candidate.expires_at))||Date.parse(candidate.expiresAt||candidate.expires_at)<=now.getTime())throw new Error('El candidato debe revalidarse antes de aplicarlo');
    if(!await confirm(candidate))return {cancelled:true};
    return callRpc('admin_apply_replacement',{p_candidate_id:candidate.id,p_notification_id:notificationId||null});
  }
  async function discardAtomically({candidateId,notificationId,callRpc}){
    return callRpc('admin_discard_replacement',{p_candidate_id:candidateId,p_notification_id:notificationId});
  }
  async function executeBatchWorkflow({candidateIds,callRpc,publish,afterApply}){
    await callRpc('admin_apply_replacement_batch',{p_candidate_ids:candidateIds});
    if(afterApply)await afterApply();
    let error=null;try{await publish();}catch(caught){error=caught;}
    try{await callRpc('admin_finalize_replacement_publish',{p_candidate_ids:candidateIds,p_succeeded:!error,p_error:error&&error.message});}
    catch(finalizeError){return {phase:'pending_finalize',published:!error,publishError:error,finalizeError};}
    return {phase:error?'pending_publish':'complete',published:!error,publishError:error};
  }
  async function revalidateStaleBatch({candidates,targetFor,providerForCandidate,registry,now=new Date()}){
    const eligible=[],excluded=[];
    for(const candidate of candidates){
      if(Date.parse(candidate.expiresAt||candidate.expires_at)>now.getTime()){eligible.push(candidate);continue;}
      const checked=await revalidateCandidate({candidate,target:targetFor(candidate),provider:providerForCandidate(candidate),registry,now});
      if(checked.confidence==='high')eligible.push(checked);else excluded.push({...candidate,exclusionReason:checked.revalidationReason||'revalidation_failed'});
    }
    return {eligible,excluded};
  }
  return {escapeHtml,selectOptimalCandidate,loadAdminData,searchReplacement,testProviderConfiguration,revalidateCandidate,revalidateStaleBatch,applyConfirmedReplacement,discardAtomically,executeBatchWorkflow};
}));
  function selectOptimalCandidate(candidates,providers){
    const priority=new Map(providers.map(p=>[p.id,Number(p.priority)]));
    return candidates.filter(c=>c.status==='pending'&&c.confidence==='high').sort((a,b)=>(priority.get(a.backup_provider_id)??Infinity)-(priority.get(b.backup_provider_id)??Infinity)||Date.parse(b.checked_at)-Date.parse(a.checked_at))[0]||null;
  }
  async function loadAdminData(client){
    const unwrap=async q=>{const r=await q;if(r.error)throw r.error;return r.data||[]};
    const [notifications,candidates,sources,events,providers]=await Promise.all([
      unwrap(client.from('admin_notifications').select('*').order('created_at',{ascending:false})),unwrap(client.from('replacement_candidates').select('*').order('created_at',{ascending:false})),unwrap(client.from('admin_source_health_view').select('*').order('health_last_check',{ascending:false})),unwrap(client.from('source_replacement_events').select('*').order('created_at',{ascending:false})),unwrap(client.from('backup_providers').select('*').order('priority'))]);
    return {notifications,candidates,sources,events,providers};
  }
