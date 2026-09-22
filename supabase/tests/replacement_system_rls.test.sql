begin;
select plan(19);

select has_table('public', 'backup_providers', 'backup providers table exists');
select has_table('public', 'replacement_candidates', 'replacement candidates table exists');
select has_table('public', 'admin_notifications', 'admin notifications table exists');
select has_table('public', 'source_replacement_events', 'replacement audit table exists');

set local role anon;
select throws_ok($$ select * from public.backup_providers $$, '42501', null, 'anon cannot select providers');
select throws_ok($$ insert into public.backup_providers(name, adapter_name, priority) values ('x','x',1) $$, '42501', null, 'anon cannot insert providers');
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","app_metadata":{"role":"viewer"}}', true);
select is_empty($$ select * from public.backup_providers $$, 'non-admin cannot select providers');
select throws_ok($$ insert into public.backup_providers(name, adapter_name, priority) values ('x','x',1) $$, '42501', null, 'non-admin cannot insert providers');
select is_empty($$ update public.backup_providers set name = 'x' returning id $$, 'non-admin cannot update providers');
select is_empty($$ delete from public.backup_providers returning id $$, 'non-admin cannot delete providers');

select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","app_metadata":{"role":"admin"}}', true);
insert into public.backup_providers(name, adapter_name, priority) values ('Template', 'example-provider', 1);
select results_eq($$ select name from public.backup_providers $$, array['Template'::text], 'admin can select providers');
select lives_ok($$ update public.backup_providers set is_active = false where name = 'Template' $$, 'admin can update providers');
select lives_ok($$ delete from public.backup_providers where name = 'Template' $$, 'admin can delete providers');

select col_is_fk('replacement_candidates', 'source_id', 'candidate source has foreign key');
select col_is_fk('replacement_candidates', 'backup_provider_id', 'candidate provider has foreign key');
select col_is_fk('admin_notifications', 'candidate_id', 'notification candidate has foreign key');
select col_is_fk('source_replacement_events', 'candidate_id', 'audit candidate has foreign key');
select has_index('public', 'backup_providers', 'backup_providers_active_priority_idx', 'active priority lookup is indexed');
select has_index('public', 'replacement_candidates', 'replacement_candidates_source_status_idx', 'candidate source/status lookup is indexed');

select * from finish();
rollback;
