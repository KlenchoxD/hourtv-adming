begin;
select plan(32);

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

-- 3. Privilegios de authenticated sobre tablas materializadas (solo SELECT, NO INSERT/UPDATE/DELETE)
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

-- 4. Aislamiento entre usuarios en push_profile_operations
select throws_ok(
  $$ select public.push_profile_operations('b2222222-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '[]'::jsonb) $$,
  '42501', null,
  '6. user 1 cannot push operations to profile owned by user 2'
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
  '7. user 1 pushes initial batch of 2 operations'
);

select is(
  (select latest_revision from public.profile_sync_metadata where profile_id = 'a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  2::bigint,
  '8. latest_revision incremented monotonically to 2'
);

select is(
  (select is_favorite from public.profile_favorites where profile_id = 'a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and content_key = 'movie:1'),
  true,
  '9. favorite_add materialized in profile_favorites'
);

select is(
  (select position_ms from public.profile_playback_progress where profile_id = 'a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and content_key = 'movie:1'),
  0::bigint,
  '10. restart initialized position_ms to 0'
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
  '11. re-sending exact same operation returns duplicate'
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
  '12. reusing operation_id with altered operation_type raises conflict'
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
  '13. reusing operation_id with altered title_id raises conflict'
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
  '14. regressive client_sequence (1 <= 2) is rejected'
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
  '15. episode_id without title_id is rejected'
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
  '16. episode_id belonging to different title_id is rejected'
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
  '17. favorite_add with non-empty payload is rejected'
);

-- 10. Progreso y eventos demorados entre sesiones (ignored_stale)
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
  '18. advance active session 1 to 1500000ms'
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
  '19. device 2 restarts content creating session 2 at 0ms'
);

select is(
  (select playback_session_id from public.profile_playback_progress where profile_id = 'a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and content_key = 'movie:1'),
  '22222222-0000-0000-0000-000000000002'::uuid,
  '20. active session is now session 2'
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
  '21. delayed update from superseded session 1 is marked ignored_stale'
);

select is(
  (select position_ms from public.profile_playback_progress where profile_id = 'a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and content_key = 'movie:1'),
  0::bigint,
  '22. session 2 position remains intact at 0ms'
);

-- 11. Pull incremental con paginación keyset y orden explícito
select is(
  (select jsonb_array_length(res->'operations') from public.pull_profile_changes('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 0, 2) as res),
  2,
  '23. pull_profile_changes page 1 returns 2 operations'
);

select is(
  (select (res->>'has_more')::boolean from public.pull_profile_changes('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 0, 2) as res),
  true,
  '24. pull_profile_changes has_more is true when more operations exist'
);

-- 12. get_profile_snapshot para perfil nuevo, existente y aislamiento
select throws_ok(
  $$ select public.get_profile_snapshot('b2222222-bbbb-bbbb-bbbb-bbbbbbbbbbbb') $$,
  '42501', null,
  '25. user 1 cannot snapshot profile owned by user 2'
);

select lives_ok(
  $$ select public.get_profile_snapshot('a2222222-aaaa-aaaa-aaaa-aaaaaaaaaaaa') $$,
  '26. get_profile_snapshot for brand new profile with zero operations succeeds'
);

select is(
  (select (res->>'snapshot_revision')::bigint from public.get_profile_snapshot('a2222222-aaaa-aaaa-aaaa-aaaaaaaaaaaa') as res),
  0::bigint,
  '27. brand new profile snapshot has revision 0'
);

-- 13. Máquina de estados en update_guest_import_audit
select throws_ok(
  $$ select public.update_guest_import_audit('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000099', 'failed', 0, 0, 0, 'Error') $$,
  '22023', null,
  '28. brand new batch cannot start directly as failed'
);

select lives_ok(
  $$ select public.update_guest_import_audit('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000099', 'in_progress', 5, 2, 10, null) $$,
  '29. new import batch starts as in_progress'
);

select lives_ok(
  $$ select public.update_guest_import_audit('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000099', 'completed', 5, 2, 10, null) $$,
  '30. import batch transitions to completed'
);

select throws_ok(
  $$ select public.update_guest_import_audit('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000099', 'in_progress', 5, 2, 10, null) $$,
  '22023', null,
  '31. completed import batch cannot transition back to in_progress'
);

-- 14. Permisos de funciones de mantenimiento restringidas a service_role
select throws_ok(
  $$ select public.compact_profile_operations('a1111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 30, 1000) $$,
  '42501', null,
  '32. authenticated user cannot execute compact_profile_operations'
);

select * from finish();
rollback;
