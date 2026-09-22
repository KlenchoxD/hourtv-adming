create or replace function public.admin_finalize_replacement_publish(p_candidate_ids uuid[],p_succeeded boolean,p_error text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare affected integer; first_candidate uuid; first_source uuid;
begin
  if not public.is_admin() then raise exception using errcode='42501',message='admin required'; end if;
  select c.id,c.source_id into first_candidate,first_source from public.replacement_candidates c where c.id=any(p_candidate_ids) order by c.id limit 1;
  if first_candidate is null then raise exception using errcode='23503',message='candidates not found'; end if;
  if p_succeeded then
    update public.admin_notifications n set status='resolved',updated_at=now()
      where n.candidate_id=any(p_candidate_ids) and n.status in ('processing','failed');
    get diagnostics affected=row_count;
    if affected=0 then return jsonb_build_object('ok',true,'already_finalized',true); end if;
    update public.admin_notifications set status='resolved',is_read=true,read_at=coalesce(read_at,now()),updated_at=now()
      where notification_type='publish_failed' and candidate_id=any(p_candidate_ids) and status='open';
    insert into public.admin_notifications(notification_type,source_id,candidate_id,message,status,is_read,read_at)
      values('publish_completed',first_source,first_candidate,cardinality(p_candidate_ids)||' reemplazos publicados.','resolved',true,now());
  else
    update public.admin_notifications n set status='failed',updated_at=now()
      where n.candidate_id=any(p_candidate_ids) and n.status='processing';
    get diagnostics affected=row_count;
    if affected=0 then return jsonb_build_object('ok',true,'already_finalized',true); end if;
    insert into public.admin_notifications(notification_type,source_id,candidate_id,message,status)
      select 'publish_failed',c.source_id,c.id,'Publicación pendiente: '||coalesce(nullif(p_error,''),'error desconocido'),'open'
      from public.replacement_candidates c where c.id=any(p_candidate_ids);
  end if;
  return jsonb_build_object('ok',true,'published',p_succeeded);
end $$;

revoke all on function public.admin_finalize_replacement_publish(uuid[],boolean,text) from public,anon;
grant execute on function public.admin_finalize_replacement_publish(uuid[],boolean,text) to authenticated;
