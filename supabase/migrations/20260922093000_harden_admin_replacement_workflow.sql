create table public.replacement_search_attempts (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null references public.sources(id) on delete cascade,
  backup_provider_id uuid references public.backup_providers(id) on delete set null,
  outcome text not null,
  detail jsonb not null default '{}'::jsonb check (jsonb_typeof(detail)='object'),
  created_at timestamptz not null default now()
);
alter table public.replacement_search_attempts enable row level security;
revoke all on public.replacement_search_attempts from public,anon,authenticated;
grant select,insert on public.replacement_search_attempts to authenticated;
create policy replacement_search_attempts_admin_select on public.replacement_search_attempts for select to authenticated using ((select public.is_admin()));
create policy replacement_search_attempts_admin_insert on public.replacement_search_attempts for insert to authenticated with check ((select public.is_admin()));

-- La vista security_invoker necesita que el administrador también pueda ver
-- las filas padre no publicadas; los usuarios normales conservan sus filtros.
create policy titles_admin_select on public.titles for select to authenticated using ((select public.is_admin()));
create policy seasons_admin_select on public.seasons for select to authenticated using ((select public.is_admin()));
create policy episodes_admin_select on public.episodes for select to authenticated using ((select public.is_admin()));
create policy sources_admin_select on public.sources for select to authenticated using ((select public.is_admin()));

create or replace function public.admin_apply_replacement(p_candidate_id uuid,p_notification_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.replacement_candidates; s public.sources; n public.admin_notifications;
begin
  if not public.is_admin() then raise exception using errcode='42501',message='admin required'; end if;
  select * into c from public.replacement_candidates where id=p_candidate_id for update;
  if not found or c.status<>'pending' or c.confidence<>'high' or not c.is_reproducible or c.expires_at<=now() then
    raise exception using errcode='23514',message='candidate is not eligible';
  end if;
  select * into s from public.sources where id=c.source_id for update;
  if not found then raise exception using errcode='23503',message='source not found'; end if;
  if s.health_status<>'down' then raise exception using errcode='23514',message='only confirmed down sources can be replaced'; end if;
  if exists(select 1 from public.sources other where other.id<>s.id and other.deleted_at is null and other.url=c.proposed_url
    and other.title_id is not distinct from s.title_id and other.episode_id is not distinct from s.episode_id) then
    raise exception using errcode='23505',message='replacement URL already exists for content';
  end if;
  if p_notification_id is not null then
    select * into n from public.admin_notifications where id=p_notification_id and candidate_id=c.id for update;
    if not found then raise exception using errcode='23503',message='notification does not match candidate'; end if;
  end if;
  update public.sources set url=c.proposed_url,name=coalesce(nullif(c.proposed_name,''),s.name),health_status='active',
    health_consecutive_failures=0,health_last_error=null,updated_at=now() where id=s.id;
  update public.replacement_candidates set status='applied',updated_at=now() where id=c.id;
  if p_notification_id is not null then update public.admin_notifications set status='processing',is_read=true,read_at=coalesce(read_at,now()),updated_at=now() where id=p_notification_id; end if;
  insert into public.source_replacement_events(source_id,candidate_id,event_type,previous_state,resulting_state)
  values(s.id,c.id,'applied',jsonb_build_object('url',s.url,'name',s.name,'order_index',s.order_index,'language_id',s.language_id),
    jsonb_build_object('url',c.proposed_url,'name',coalesce(nullif(c.proposed_name,''),s.name),'order_index',s.order_index,'language_id',s.language_id));
  return jsonb_build_object('ok',true,'source_id',s.id,'previous_url',s.url,'url',c.proposed_url);
end $$;

create or replace function public.admin_apply_replacement_batch(p_candidate_ids uuid[])
returns jsonb language plpgsql security definer set search_path='' as $$
declare cid uuid; results jsonb='[]'::jsonb;
begin
  if not public.is_admin() then raise exception using errcode='42501',message='admin required'; end if;
  foreach cid in array p_candidate_ids loop
    results=results||public.admin_apply_replacement(cid,null);
    update public.admin_notifications set status='processing',is_read=true,read_at=coalesce(read_at,now()),updated_at=now()
      where candidate_id=cid and status='open';
  end loop;
  return jsonb_build_object('ok',true,'results',results);
end $$;

create or replace function public.admin_discard_replacement(p_candidate_id uuid,p_notification_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.replacement_candidates;
begin
  if not public.is_admin() then raise exception using errcode='42501',message='admin required'; end if;
  select * into c from public.replacement_candidates where id=p_candidate_id for update;
  if not found then raise exception using errcode='23503',message='candidate not found'; end if;
  perform 1 from public.admin_notifications where id=p_notification_id and candidate_id=c.id for update;
  if not found then raise exception using errcode='23503',message='notification does not match candidate'; end if;
  update public.replacement_candidates set status='discarded',updated_at=now() where id=c.id;
  update public.admin_notifications set status='dismissed',is_read=true,read_at=coalesce(read_at,now()),updated_at=now() where id=p_notification_id;
  insert into public.source_replacement_events(source_id,candidate_id,event_type,previous_state,resulting_state)
    values(c.source_id,c.id,'discarded',jsonb_build_object('candidate_status',c.status),jsonb_build_object('candidate_status','discarded'));
  return jsonb_build_object('ok',true);
end $$;

create or replace function public.admin_finalize_replacement_publish(p_candidate_ids uuid[],p_succeeded boolean,p_error text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare affected integer;
begin
  if not public.is_admin() then raise exception using errcode='42501',message='admin required'; end if;
  if p_succeeded then
    update public.admin_notifications n set status='resolved',updated_at=now()
      where n.candidate_id=any(p_candidate_ids) and n.status='processing';
    get diagnostics affected=row_count;
    if affected=0 then return jsonb_build_object('ok',true,'already_finalized',true); end if;
    insert into public.admin_notifications(notification_type,message,status,is_read,read_at)
      values('publish_completed',cardinality(p_candidate_ids)||' reemplazos publicados.','resolved',true,now());
  else
    update public.admin_notifications n set status='failed',updated_at=now()
      where n.candidate_id=any(p_candidate_ids) and n.status='processing';
    get diagnostics affected=row_count;
    if affected=0 then return jsonb_build_object('ok',true,'already_finalized',true); end if;
    insert into public.admin_notifications(notification_type,message,status)
      values('publish_failed','Publicación pendiente: '||coalesce(nullif(p_error,''),'error desconocido'),'open');
  end if;
  return jsonb_build_object('ok',true,'published',p_succeeded);
end $$;

create or replace function public.admin_persist_replacement_search(p_source_id uuid,p_provider_id uuid,p_attempts jsonb,p_candidate jsonb default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.sources; item jsonb; candidate_id uuid;
begin
  if not public.is_admin() then raise exception using errcode='42501',message='admin required'; end if;
  select * into s from public.sources where id=p_source_id for update;
  if not found then raise exception using errcode='23503',message='source not found'; end if;
  if s.health_status<>'down' then raise exception using errcode='23514',message='search only allowed for confirmed down source'; end if;
  if jsonb_typeof(p_attempts)<>'array' then raise exception using errcode='23514',message='attempts must be array'; end if;
  for item in select value from jsonb_array_elements(p_attempts) loop
    insert into public.replacement_search_attempts(source_id,backup_provider_id,outcome,detail)
      values(p_source_id,nullif(item->>'providerId','')::uuid,coalesce(item->>'reason','unknown'),jsonb_build_object('error',item->>'error'));
  end loop;
  if p_candidate is not null then
    if p_provider_id is null then raise exception using errcode='23514',message='provider required for candidate'; end if;
    insert into public.replacement_candidates(source_id,backup_provider_id,proposed_url,proposed_name,proposed_language_code,content_type,tmdb_id,normalized_title,release_year,season_number,episode_number,is_reproducible,confidence,confidence_reasons,checked_at,expires_at)
    values(p_source_id,p_provider_id,p_candidate->>'proposed_url',p_candidate->>'proposed_name',p_candidate->>'proposed_language_code',p_candidate->>'content_type',nullif(p_candidate->>'tmdb_id','')::integer,p_candidate->>'normalized_title',nullif(p_candidate->>'release_year','')::integer,nullif(p_candidate->>'season_number','')::integer,nullif(p_candidate->>'episode_number','')::integer,coalesce((p_candidate->>'is_reproducible')::boolean,false),p_candidate->>'confidence',coalesce(p_candidate->'confidence_reasons','[]'::jsonb),(p_candidate->>'checked_at')::timestamptz,(p_candidate->>'expires_at')::timestamptz)
    returning id into candidate_id;
    update public.backup_providers set successful_searches=successful_searches+1,updated_at=now() where id=p_provider_id;
    insert into public.admin_notifications(notification_type,source_id,candidate_id,message)
      values('replacement_found',p_source_id,candidate_id,'Se encontró un reemplazo de confianza alta.');
  else
    insert into public.admin_notifications(notification_type,source_id,message) values('replacement_unavailable',p_source_id,'No se encontró un reemplazo de confianza alta.');
  end if;
  return jsonb_build_object('ok',true,'candidate_id',candidate_id);
end $$;

revoke all on function public.admin_apply_replacement(uuid,uuid),public.admin_apply_replacement_batch(uuid[]),
  public.admin_discard_replacement(uuid,uuid),public.admin_finalize_replacement_publish(uuid[],boolean,text) from public,anon;
revoke all on function public.admin_persist_replacement_search(uuid,uuid,jsonb,jsonb) from public,anon;
grant execute on function public.admin_apply_replacement(uuid,uuid),public.admin_apply_replacement_batch(uuid[]),
  public.admin_discard_replacement(uuid,uuid),public.admin_finalize_replacement_publish(uuid[],boolean,text) to authenticated;
grant execute on function public.admin_persist_replacement_search(uuid,uuid,jsonb,jsonb) to authenticated;
