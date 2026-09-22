begin;
select plan(45);

select has_table('public', 'backup_providers', 'backup providers table exists');
select has_table('public', 'replacement_candidates', 'replacement candidates table exists');
select has_table('public', 'admin_notifications', 'admin notifications table exists');
select has_table('public', 'source_replacement_events', 'replacement audit table exists');

insert into auth.users(id, aud, role) values ('22222222-2222-2222-2222-222222222222', 'authenticated', 'authenticated');
insert into public.languages(id, code, name) values ('10000000-0000-0000-0000-000000000001', 'es', 'Español');
insert into public.titles(id, media_type, title, normalized_title, year, tmdb_id)
values ('10000000-0000-0000-0000-000000000002', 'movie', 'Amélie', 'amelie', 2001, 42);
insert into public.sources(id, title_id, language_id, name, url, health_status)
values ('10000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000002',
  '10000000-0000-0000-0000-000000000001', 'Old', 'https://video.example/old', 'down');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","app_metadata":{"role":"admin"}}', true);
select lives_ok($$ insert into public.backup_providers(id, name, adapter_name, priority)
 values ('20000000-0000-0000-0000-000000000001', 'Template', 'example-provider', 1) $$, 'admin seeds provider');
select lives_ok($$ insert into public.replacement_candidates(id, source_id, backup_provider_id, proposed_url,
 proposed_language_code, content_type, tmdb_id, normalized_title, release_year, is_reproducible, confidence, checked_at, expires_at)
 values ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000003',
 '20000000-0000-0000-0000-000000000001', 'https://video.example/new', 'es', 'movie', 42, 'amelie', 2001,
 true, 'high', now(), now() + interval '1 day') $$, 'admin seeds coherent candidate');
select lives_ok($$ insert into public.admin_notifications(id, notification_type, source_id, candidate_id, message)
 values ('20000000-0000-0000-0000-000000000003', 'replacement_found', '10000000-0000-0000-0000-000000000003',
 '20000000-0000-0000-0000-000000000002', 'Replacement found') $$, 'admin seeds notification');
select lives_ok($$ insert into public.source_replacement_events(id, source_id, candidate_id, event_type)
 values ('20000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000003',
 '20000000-0000-0000-0000-000000000002', 'approved') $$, 'admin seeds audit event');

select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","app_metadata":{"role":"viewer"}}', true);
select is_empty($$ select * from public.backup_providers $$, 'non-admin cannot select providers');
select throws_ok($$ insert into public.backup_providers(name, adapter_name, priority) values ('x','x',9) $$, '42501', null, 'non-admin cannot insert providers');
select is_empty($$ update public.backup_providers set name = 'x' returning id $$, 'non-admin cannot update providers');
select is_empty($$ delete from public.backup_providers returning id $$, 'non-admin cannot delete providers');
select is_empty($$ select * from public.replacement_candidates $$, 'non-admin cannot select candidates');
select throws_ok($$ insert into public.replacement_candidates(source_id) values (gen_random_uuid()) $$, '42501', null, 'non-admin cannot insert candidates');
select is_empty($$ update public.replacement_candidates set status = 'discarded' returning id $$, 'non-admin cannot update candidates');
select is_empty($$ delete from public.replacement_candidates returning id $$, 'non-admin cannot delete candidates');
select is_empty($$ select * from public.admin_notifications $$, 'non-admin cannot select notifications');
select throws_ok($$ insert into public.admin_notifications(message) values ('x') $$, '42501', null, 'non-admin cannot insert notifications');
select is_empty($$ update public.admin_notifications set status = 'dismissed' returning id $$, 'non-admin cannot update notifications');
select is_empty($$ delete from public.admin_notifications returning id $$, 'non-admin cannot delete notifications');
select is_empty($$ select * from public.source_replacement_events $$, 'non-admin cannot select events');
select throws_ok($$ insert into public.source_replacement_events(source_id) values (gen_random_uuid()) $$, '42501', null, 'non-admin cannot insert events');
select throws_ok($$ update public.source_replacement_events set event_type = 'failed' $$, '42501', null, 'events cannot be updated');
select throws_ok($$ delete from public.source_replacement_events $$, '42501', null, 'events cannot be deleted');

select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","app_metadata":{"role":"admin"}}', true);
select results_eq($$ select count(*)::bigint from public.backup_providers $$, array[1::bigint], 'admin selects providers');
select results_eq($$ select count(*)::bigint from public.replacement_candidates $$, array[1::bigint], 'admin selects candidates');
select results_eq($$ select count(*)::bigint from public.admin_notifications $$, array[1::bigint], 'admin selects notifications');
select results_eq($$ select count(*)::bigint from public.source_replacement_events $$, array[1::bigint], 'admin selects events');
select lives_ok($$ update public.backup_providers set priority = 2 where name = 'Template' $$, 'admin updates providers');
select lives_ok($$ insert into public.backup_providers(id, name, adapter_name, priority)
 values ('20000000-0000-0000-0000-000000000005', 'Second', 'example-provider', 3) $$, 'admin inserts second provider');
select lives_ok($$ update public.backup_providers set priority = case priority when 2 then 3 else 2 end
 where priority in (2, 3) $$, 'admin atomically reorders provider priorities');
select lives_ok($$ update public.replacement_candidates set status = 'approved' where id = '20000000-0000-0000-0000-000000000002' $$, 'admin updates candidates');
select lives_ok($$ update public.admin_notifications set is_read = true, read_at = now() where id = '20000000-0000-0000-0000-000000000003' $$, 'admin updates notifications');
select throws_ok($$ update public.source_replacement_events set event_type = 'failed' $$, '42501', null, 'admin cannot update append-only events');
select throws_ok($$ delete from public.source_replacement_events $$, '42501', null, 'admin cannot delete append-only events');
select throws_ok($$ insert into public.replacement_candidates(source_id, backup_provider_id, proposed_url,
 proposed_language_code, content_type, tmdb_id, normalized_title, release_year, is_reproducible, confidence, checked_at, expires_at)
 values ('10000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000001',
 'https://video.example/wrong', 'es', 'movie', 999, 'amelie', 2001, true, 'high', now(), now() + interval '1 day') $$,
 '23514', 'high replacement candidate evidence does not match source', 'high candidate rejects wrong TMDB');
select throws_ok($$ insert into public.replacement_candidates(source_id, backup_provider_id, proposed_url,
 proposed_language_code, content_type, tmdb_id, normalized_title, release_year, is_reproducible, confidence, checked_at, expires_at)
 values ('10000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000001',
 'https://video.example/fake', 'es', 'movie', 42, 'amelie', 2001, false, 'high', now(), now() + interval '1 day') $$,
 '23514', 'high replacement candidate evidence does not match source', 'high candidate must be reproducible');
select lives_ok($$ delete from public.admin_notifications where id = '20000000-0000-0000-0000-000000000003' $$, 'admin deletes notifications');
select lives_ok($$ delete from public.replacement_candidates where id = '20000000-0000-0000-0000-000000000002' $$, 'admin deletes candidates');
select lives_ok($$ delete from public.backup_providers $$, 'admin deletes providers');

select col_is_fk('replacement_candidates', 'source_id', 'candidate source has foreign key');
select col_is_fk('replacement_candidates', 'backup_provider_id', 'candidate provider has foreign key');
select col_is_fk('replacement_candidates', 'proposed_language_code', 'candidate language references languages');
select has_index('public', 'backup_providers', 'backup_providers_active_priority_idx', 'priority lookup is indexed');
select constraint_is_deferrable('public', 'backup_providers', 'backup_providers_priority_unique', 'priority uniqueness is deferred for reordering');

select * from finish();
rollback;
