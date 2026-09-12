begin;
select plan(54);

-- 1. Setup mock users in auth.users
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, confirmation_token, recovery_token, email_change_token_new, email_change)
values
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'user1@example.com', 'encrypted', now(), now(), now(), '', '', '', ''),
  ('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'user2@example.com', 'encrypted', now(), now(), now(), '', '', '', '')
on conflict (id) do nothing;

-- Setup profiles for User 1 and User 2
insert into public.account_profiles (id, owner_id, name, avatar_id, is_kids, position)
values
  ('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'User1 Profile', 'adult_1', false, 0),
  ('a2222222-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'User1 Profile 2', 'adult_2', false, 1),
  ('b2222222-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22222222-2222-2222-2222-222222222222', 'User2 Profile', 'adult_1', false, 0)
on conflict do nothing;

-- Setup mock titles, season and episode for catalog validation tests
insert into public.titles (id, legacy_id, media_type, title, normalized_title, is_kids_safe)
values
  ('c1111111-1111-1111-1111-111111111111', 'title_1', 'series', 'Serie Aprobada', 'serie aprobada', true),
  ('c2222222-2222-2222-2222-222222222222', 'title_2', 'series', 'Otra Serie', 'otra serie', true)
on conflict do nothing;

insert into public.seasons (id, title_id, season_number, name)
values
  ('d1111111-1111-1111-1111-111111111111', 'c1111111-1111-1111-1111-111111111111', 1, 'Temporada 1')
on conflict do nothing;

insert into public.episodes (id, season_id, episode_number, title)
values
  ('e1111111-eeee-eeee-eeee-eeeeeeeeeeee', 'd1111111-1111-1111-1111-111111111111', 1, 'Episodio 1')
on conflict do nothing;

-- 2. Privilegios de anon (completamente denegado)
set local role anon;
set local "request.jwt.claim.sub" to '';
set local "request.jwt.claim.role" to 'anon';

select throws_ok(
  $$ select count(*) from public.profile_operations $$,
  '42501', null,
  '1. anon cannot select from profile_operations'
);

select throws_ok(
  $$ select public.push_profile_operations('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '[]'::jsonb) $$,
  '42501', null,
  '2. anon cannot execute push_profile_operations'
);

select throws_ok(
  $$ select public.pull_profile_changes('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 0, 10) $$,
  '42501', null,
  '3. anon cannot execute pull_profile_changes'
);

-- 3. Privilegios de authenticated sobre tablas materializadas y ledger (solo SELECT; INSERT, UPDATE y DELETE directos rechazados)
set local role authenticated;
set local "request.jwt.claim.sub" to '11111111-1111-1111-1111-111111111111';
set local "request.jwt.claim.role" to 'authenticated';

select throws_ok(
  $$ insert into public.profile_playback_progress (owner_id, profile_id, content_key, playback_session_id, position_ms, duration_ms, fraction, is_completed, server_revision)
     values ('11111111-1111-1111-1111-111111111111', 'a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'movie:1', gen_random_uuid(), 100, 1000, 0.1, false, 1) $$,
  '42501', null,
  '4. authenticated user cannot directly insert into profile_playback_progress'
);

select throws_ok(
  $$ insert into public.profile_sync_metadata (profile_id, owner_id, latest_revision)
     values ('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 99) $$,
  '42501', null,
  '5. authenticated user cannot directly insert into profile_sync_metadata'
);

select throws_ok(
  $$ update public.profile_operations set device_id = 'hacked' $$,
  '42501', null,
  '6. authenticated user cannot directly update profile_operations'
);

select throws_ok(
  $$ delete from public.profile_operations $$,
  '42501', null,
  '7. authenticated user cannot directly delete from profile_operations'
);

select throws_ok(
  $$ update public.profile_favorites set is_favorite = false $$,
  '42501', null,
  '8. authenticated user cannot directly update profile_favorites'
);

select throws_ok(
  $$ delete from public.profile_favorites $$,
  '42501', null,
  '9. authenticated user cannot directly delete from profile_favorites'
);

select throws_ok(
  $$ update public.guest_import_audit set status = 'failed' $$,
  '42501', null,
  '10. authenticated user cannot directly update guest_import_audit'
);

select throws_ok(
  $$ delete from public.guest_import_audit $$,
  '42501', null,
  '11. authenticated user cannot directly delete from guest_import_audit'
);

-- 4. Aislamiento entre usuarios en push_profile_operations y update_guest_import_audit
select throws_ok(
  $$ select public.push_profile_operations('b2222222-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '[]'::jsonb) $$,
  '42501', null,
  '12. user 1 cannot push operations to profile owned by user 2'
);

select throws_ok(
  $$ select public.update_guest_import_audit('b2222222-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '00000000-0000-0000-0000-000000000099', 'in_progress', 5, 2, 10, null) $$,
  '42501', null,
  '13. user 1 cannot audit profile owned by user 2'
);

-- 5. Inserción inicial en perfil nuevo y asignación de revisiones sin saltos
select lives_ok(
  $$ select public.push_profile_operations('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', jsonb_build_array(
    jsonb_build_object(
      'operation_id', '00000000-0000-0000-0000-000000000001',
      'device_id', 'dev_1',
      'client_sequence', 1,
      'operation_type', 'favorite_add',
      'content_key', 'movie:1',
      'payload', '{}'::jsonb
    ),
    jsonb_build_object(
      'operation_id', '00000000-0000-0000-0000-000000000002',
      'device_id', 'dev_1',
      'client_sequence', 2,
      'operation_type', 'restart',
      'playback_session_id', '11111111-0000-0000-0000-000000000001',
      'content_key', 'movie:1',
      'payload', jsonb_build_object('duration_ms', 7200000)
    )
  )) $$,
  '14. user 1 pushes initial batch of 2 operations'
);

select is(
  (select latest_revision from public.profile_sync_metadata where profile_id = 'a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  2::bigint,
  '15. latest_revision incremented monotonically to 2'
);

select is(
  (select is_favorite from public.profile_favorites where profile_id = 'a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and content_key = 'movie:1'),
  true,
  '16. favorite_add materialized in profile_favorites'
);

select is(
  (select position_ms from public.profile_playback_progress where profile_id = 'a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and content_key = 'movie:1'),
  0::bigint,
  '17. restart initialized position_ms to 0'
);

-- 6. Idempotencia: Mismo operation_id con contenido idéntico devuelve duplicate
select is(
  (select (res->0->>'status') from public.push_profile_operations('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', jsonb_build_array(
    jsonb_build_object(
      'operation_id', '00000000-0000-0000-0000-000000000001',
      'device_id', 'dev_1',
      'client_sequence', 1,
      'operation_type', 'favorite_add',
      'content_key', 'movie:1',
      'payload', '{}'::jsonb
    )
  )) as res),
  'duplicate',
  '18. re-sending exact same operation returns duplicate'
);

-- 7. Idempotencia con alteración de payload o claves produce conflicto
select throws_ok(
  $$ select public.push_profile_operations('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', jsonb_build_array(
    jsonb_build_object(
      'operation_id', '00000000-0000-0000-0000-000000000001',
      'device_id', 'dev_1',
      'client_sequence', 1,
      'operation_type', 'favorite_remove',
      'content_key', 'movie:1',
      'payload', '{}'::jsonb
    )
  )) $$,
  '23505', null,
  '19. reusing operation_id with altered operation_type raises conflict'
);

select throws_ok(
  $$ select public.push_profile_operations('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', jsonb_build_array(
    jsonb_build_object(
      'operation_id', '00000000-0000-0000-0000-000000000001',
      'device_id', 'dev_1',
      'client_sequence', 1,
      'operation_type', 'favorite_add',
      'content_key', 'movie:1',
      'title_id', 'c1111111-1111-1111-1111-111111111111',
      'payload', '{}'::jsonb
    )
  )) $$,
  '23505', null,
  '20. reusing operation_id with altered title_id raises conflict'
);

-- 8. Monotonicidad de secuencia de dispositivo: secuencia regresiva rechazada
select throws_ok(
  $$ select public.push_profile_operations('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', jsonb_build_array(
    jsonb_build_object(
      'operation_id', '00000000-0000-0000-0000-000000000003',
      'device_id', 'dev_1',
      'client_sequence', 1,
      'operation_type', 'favorite_add',
      'content_key', 'movie:2',
      'payload', '{}'::jsonb
    )
  )) $$,
  '22023', null,
  '21. regressive client_sequence (1 <= 2) is rejected'
);

-- 9. Validación de payload y coherencia de episodio
select throws_ok(
  $$ select public.push_profile_operations('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', jsonb_build_array(
    jsonb_build_object(
      'operation_id', '00000000-0000-0000-0000-000000000004',
      'device_id', 'dev_1',
      'client_sequence', 3,
      'operation_type', 'progress_update',
      'playback_session_id', '11111111-0000-0000-0000-000000000001',
      'content_key', 'episode:1',
      'episode_id', 'e1111111-eeee-eeee-eeee-eeeeeeeeeeee',
      'payload', jsonb_build_object('position_ms', 500, 'duration_ms', 1000)
    )
  )) $$,
  '22023', null,
  '22. episode_id without title_id is rejected'
);

select throws_ok(
  $$ select public.push_profile_operations('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', jsonb_build_array(
    jsonb_build_object(
      'operation_id', '00000000-0000-0000-0000-000000000004',
      'device_id', 'dev_1',
      'client_sequence', 3,
      'operation_type', 'progress_update',
      'playback_session_id', '11111111-0000-0000-0000-000000000001',
      'content_key', 'episode:1',
      'title_id', 'c2222222-2222-2222-2222-222222222222',
      'episode_id', 'e1111111-eeee-eeee-eeee-eeeeeeeeeeee',
      'payload', jsonb_build_object('position_ms', 500, 'duration_ms', 1000)
    )
  )) $$,
  '22023', null,
  '23. episode_id belonging to different title_id is rejected'
);

select throws_ok(
  $$ select public.push_profile_operations('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', jsonb_build_array(
    jsonb_build_object(
      'operation_id', '00000000-0000-0000-0000-000000000005',
      'device_id', 'dev_1',
      'client_sequence', 3,
      'operation_type', 'favorite_add',
      'content_key', 'movie:3',
      'payload', jsonb_build_object('extra', 'unallowed')
    )
  )) $$,
  '22023', null,
  '24. favorite_add with non-empty payload is rejected'
);

-- 10. Progreso y eventos demorados entre sesiones (ignored_stale recuperado en pull)
-- Dispositivo 1 avanza sesión 1
select lives_ok(
  $$ select public.push_profile_operations('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', jsonb_build_array(
    jsonb_build_object(
      'operation_id', '00000000-0000-0000-0000-000000000006',
      'device_id', 'dev_1',
      'client_sequence', 3,
      'operation_type', 'progress_update',
      'playback_session_id', '11111111-0000-0000-0000-000000000001',
      'content_key', 'movie:1',
      'payload', jsonb_build_object('position_ms', 1500000, 'duration_ms', 7200000)
    )
  )) $$,
  '25. advance active session 1 to 1500000ms'
);

-- Dispositivo 2 reinicia y crea sesión 2
select lives_ok(
  $$ select public.push_profile_operations('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', jsonb_build_array(
    jsonb_build_object(
      'operation_id', '00000000-0000-0000-0000-000000000007',
      'device_id', 'dev_2',
      'client_sequence', 1,
      'operation_type', 'restart',
      'playback_session_id', '22222222-0000-0000-0000-000000000002',
      'content_key', 'movie:1',
      'payload', jsonb_build_object('duration_ms', 7200000)
    )
  )) $$,
  '26. device 2 restarts content creating session 2 at 0ms'
);

select is(
  (select playback_session_id from public.profile_playback_progress where profile_id = 'a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and content_key = 'movie:1'),
  '22222222-0000-0000-0000-000000000002'::uuid,
  '27. active session is now session 2'
);

-- Dispositivo 1 envía evento atrasado de sesión 1 -> debe ser ignored_stale y no degradar sesión 2
select is(
  (select (res->0->>'status') from public.push_profile_operations('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', jsonb_build_array(
    jsonb_build_object(
      'operation_id', '00000000-0000-0000-0000-000000000008',
      'device_id', 'dev_1',
      'client_sequence', 4,
      'operation_type', 'progress_update',
      'playback_session_id', '11111111-0000-0000-0000-000000000001',
      'content_key', 'movie:1',
      'payload', jsonb_build_object('position_ms', 1800000, 'duration_ms', 7200000)
    )
  )) as res),
  'ignored_stale',
  '28. delayed update from superseded session 1 is marked ignored_stale'
);

select is(
  (select position_ms from public.profile_playback_progress where profile_id = 'a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and content_key = 'movie:1'),
  0::bigint,
  '29. session 2 position remains intact at 0ms'
);

-- Verificación de que pull_profile_changes entrega apply_status = ignored_stale sin suprimirlo
select is(
  (select op->>'apply_status'
   from jsonb_array_elements((public.pull_profile_changes('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 0, 100))->'operations') as op
   where op->>'operation_id' = '00000000-0000-0000-0000-000000000008'),
  'ignored_stale',
  '30. pull_profile_changes retrieves operations with apply_status = ignored_stale'
);

-- 11. Pull incremental con paginación keyset: varias páginas completas hasta has_more=false sin duplicados
-- Actualmente existen 5 operaciones en a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa (rev 1..5)
select is(
  (select jsonb_array_length(res->'operations') from public.pull_profile_changes('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 0, 2) as res),
  2,
  '31. pull_profile_changes page 1 returns 2 operations'
);

select is(
  (select (res->>'has_more')::boolean from public.pull_profile_changes('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 0, 2) as res),
  true,
  '32. pull_profile_changes page 1 has_more is true'
);

select is(
  (select jsonb_array_length(res->'operations') from public.pull_profile_changes('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 2, 2) as res),
  2,
  '33. pull_profile_changes page 2 returns 2 operations'
);

select is(
  (select (res->>'has_more')::boolean from public.pull_profile_changes('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 2, 2) as res),
  true,
  '34. pull_profile_changes page 2 has_more is true'
);

select is(
  (select jsonb_array_length(res->'operations') from public.pull_profile_changes('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 4, 2) as res),
  1,
  '35. pull_profile_changes page 3 returns 1 operation'
);

select is(
  (select (res->>'has_more')::boolean from public.pull_profile_changes('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 4, 2) as res),
  false,
  '36. pull_profile_changes page 3 has_more is false'
);

select is(
  (select jsonb_array_length(res->'operations') from public.pull_profile_changes('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 5, 2) as res),
  0,
  '37. pull_profile_changes page 4 returns 0 operations'
);

select is(
  (select (res->>'has_more')::boolean from public.pull_profile_changes('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 5, 2) as res),
  false,
  '38. pull_profile_changes page 4 has_more is false'
);

-- Verificar que la unión de páginas 1, 2 y 3 contiene exactamente 5 operaciones únicas sin duplicados
select is(
  (
    with p1 as (select jsonb_array_elements((public.pull_profile_changes('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 0, 2))->'operations') as op),
         p2 as (select jsonb_array_elements((public.pull_profile_changes('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 2, 2))->'operations') as op),
         p3 as (select jsonb_array_elements((public.pull_profile_changes('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 4, 2))->'operations') as op),
         all_ops as (select op->>'operation_id' as op_id from p1 union all select op->>'operation_id' from p2 union all select op->>'operation_id' from p3)
    select count(distinct op_id) = 5 and count(*) = 5 from all_ops
  ),
  true,
  '39. paginated operations across multiple pages contain 5 unique operations without duplicates'
);

-- 12. Checkpoint compactado que devuelve full_resync_required=true
set local role service_role;
insert into public.profile_sync_metadata (profile_id, owner_id, latest_revision, minimum_available_revision, updated_at)
values ('a2222222-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 20, 10, now())
on conflict (profile_id) do update set latest_revision = 20, minimum_available_revision = 10;
set local role authenticated;

select is(
  (select (res->>'full_resync_required')::boolean from public.pull_profile_changes('a2222222-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 0, 10) as res),
  true,
  '40. compacted checkpoint with minimum_available_revision > 1 and sinceRevision = 0 returns full_resync_required = true'
);

select is(
  (select ((res->>'has_more')::boolean = false and jsonb_array_length(res->'operations') = 0) from public.pull_profile_changes('a2222222-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 0, 10) as res),
  true,
  '41. compacted checkpoint returns empty operations array and has_more = false'
);

-- 13. Snapshot que incluye historial y aislamiento entre usuarios
select lives_ok(
  $$ select public.push_profile_operations('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', jsonb_build_array(
    jsonb_build_object(
      'operation_id', '00000000-0000-0000-0000-000000000009',
      'device_id', 'dev_1',
      'client_sequence', 5,
      'operation_type', 'history_append',
      'playback_session_id', '22222222-0000-0000-0000-000000000002',
      'content_key', 'movie:1',
      'payload', jsonb_build_object('position_ms', 7200000, 'duration_ms', 7200000)
    )
  )) $$,
  '42. push history_append operation succeeds'
);

select throws_ok(
  $$ select public.get_profile_snapshot('b2222222-bbbb-bbbb-bbbb-bbbbbbbbbbbb') $$,
  '42501', null,
  '43. user 1 cannot snapshot profile owned by user 2'
);

select lives_ok(
  $$ select public.get_profile_snapshot('a2222222-aaaa-aaaa-aaaa-aaaaaaaaaaaa') $$,
  '44. get_profile_snapshot for brand new profile with zero operations succeeds'
);

select is(
  (select (res->>'snapshot_revision')::bigint from public.get_profile_snapshot('a2222222-aaaa-aaaa-aaaa-aaaaaaaaaaaa') as res),
  20::bigint,
  '45. profile snapshot reflects latest metadata revision'
);

select is(
  (select jsonb_array_length(res->'history') > 0 from public.get_profile_snapshot('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa') as res),
  true,
  '46. get_profile_snapshot on active profile includes history entries'
);

select is(
  (select res->'history'->0->>'content_key' from public.get_profile_snapshot('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa') as res),
  'movie:1',
  '47. snapshot history contains matching content_key'
);

-- 14. Máquina de estados en update_guest_import_audit y rechazo de completed repetido con recuentos diferentes
select throws_ok(
  $$ select public.update_guest_import_audit('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000099', 'failed', 0, 0, 0, 'Error') $$,
  '22023', null,
  '48. brand new batch cannot start directly as failed'
);

select lives_ok(
  $$ select public.update_guest_import_audit('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000099', 'in_progress', 5, 2, 10, null) $$,
  '49. new import batch starts as in_progress'
);

select lives_ok(
  $$ select public.update_guest_import_audit('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000099', 'completed', 5, 2, 10, null) $$,
  '50. import batch transitions to completed'
);

select throws_ok(
  $$ select public.update_guest_import_audit('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000099', 'in_progress', 5, 2, 10, null) $$,
  '22023', null,
  '51. completed import batch cannot transition back to in_progress'
);

select lives_ok(
  $$ select public.update_guest_import_audit('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000099', 'completed', 5, 2, 10, null) $$,
  '52. repeated completed import batch with identical counts succeeds idempotently'
);

select throws_ok(
  $$ select public.update_guest_import_audit('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000099', 'completed', 99, 99, 99, null) $$,
  '23505', null,
  '53. repeated completed import batch with mismatched counts raises conflict 23505'
);

-- 15. Permisos de funciones de mantenimiento restringidas a service_role
select throws_ok(
  $$ select public.compact_profile_operations('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 30, 1000) $$,
  '42501', null,
  '54. authenticated user cannot execute compact_profile_operations'
);

-- NOTA HONESTA DE CONCURRENCIA:
-- pgTAP se ejecuta en un bloque transaccional individual ('begin; ... rollback;').
-- No es posible evaluar entrelazamiento de conexiones concurrentes reales en este archivo.
-- La concurrencia real entre múltiples clientes con secuencias paralelas y resolución
-- determinista de carreras se evalúa mediante la suite Flutter/Dart:
-- test/services/sync/profile_sync_scale_test.dart.

select * from finish();
rollback;
