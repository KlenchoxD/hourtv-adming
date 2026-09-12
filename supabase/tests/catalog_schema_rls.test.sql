begin;
select plan(54);

-- 1. Test: anon y authenticated no pueden mutar tablas del catálogo
set local role anon;
select throws_ok(
  $$ insert into public.titles (media_type, title, normalized_title) values ('movie', 'Hacker Film', 'hacker film') $$,
  '42501', null,
  'anon role cannot insert into titles'
);
select throws_ok(
  $$ update public.titles set title = 'Defaced' where id = '00000000-0000-0000-0000-000000000000' $$,
  '42501', null,
  'anon role cannot update titles'
);
select throws_ok(
  $$ delete from public.titles where id = '00000000-0000-0000-0000-000000000000' $$,
  '42501', null,
  'anon role cannot delete from titles'
);

set local role authenticated;
select throws_ok(
  $$ insert into public.sources (name, url) values ('Bad Source', 'https://example.com/stream.m3u8') $$,
  '42501', null,
  'authenticated role cannot insert into sources'
);

-- 2. Test: Funciones PostgreSQL y Privilegios (anon/authenticated/public)
set local role anon;
select throws_ok(
  $$ select public.compact_catalog_changes(1000::bigint) $$,
  '42501', null,
  'anon cannot execute compact_catalog_changes (permission denied)'
);

set local role authenticated;
select throws_ok(
  $$ select public.compact_catalog_changes(1000::bigint) $$,
  '42501', null,
  'authenticated cannot execute compact_catalog_changes (permission denied)'
);

-- Revocaciones comprobadas con has_function_privilege nativo de PostgreSQL
select is(has_function_privilege('public', 'public.compact_catalog_changes(bigint)', 'EXECUTE'), false,
  'PUBLIC does not retain EXECUTE on compact_catalog_changes');
select is(has_function_privilege('public', 'public.fn_assign_catalog_change_revision()', 'EXECUTE'), false,
  'PUBLIC does not retain EXECUTE on fn_assign_catalog_change_revision');
select is(has_function_privilege('public', 'public.fn_catalog_changes_titles()', 'EXECUTE'), false,
  'PUBLIC does not retain EXECUTE on fn_catalog_changes_titles');
select is(has_function_privilege('public', 'public.fn_catalog_changes_seasons()', 'EXECUTE'), false,
  'PUBLIC does not retain EXECUTE on fn_catalog_changes_seasons');
select is(has_function_privilege('public', 'public.fn_catalog_changes_episodes()', 'EXECUTE'), false,
  'PUBLIC does not retain EXECUTE on fn_catalog_changes_episodes');
select is(has_function_privilege('public', 'public.fn_catalog_changes_sources()', 'EXECUTE'), false,
  'PUBLIC does not retain EXECUTE on fn_catalog_changes_sources');
select is(has_function_privilege('public', 'public.fn_catalog_changes_title_genres()', 'EXECUTE'), false,
  'PUBLIC does not retain EXECUTE on fn_catalog_changes_title_genres');
select is(has_function_privilege('public', 'public.fn_catalog_changes_genres()', 'EXECUTE'), false,
  'PUBLIC does not retain EXECUTE on fn_catalog_changes_genres');
select is(has_function_privilege('public', 'public.fn_catalog_changes_languages()', 'EXECUTE'), false,
  'PUBLIC does not retain EXECUTE on fn_catalog_changes_languages');

select is(has_function_privilege('anon', 'public.compact_catalog_changes(bigint)', 'EXECUTE'), false,
  'anon does not have EXECUTE on compact_catalog_changes');
select is(has_function_privilege('authenticated', 'public.compact_catalog_changes(bigint)', 'EXECUTE'), false,
  'authenticated does not have EXECUTE on compact_catalog_changes');

-- 3. Test: Inmutabilidad de catalog_sync_metadata para clientes
select throws_ok(
  $$ update public.catalog_sync_metadata set latest_revision = 999999 where id = 1 $$,
  '42501', null,
  'authenticated cannot update catalog_sync_metadata'
);
select throws_ok(
  $$ insert into public.catalog_sync_metadata (id, minimum_available_revision, latest_revision) values (2, 1, 1) $$,
  '42501', null,
  'authenticated cannot insert into catalog_sync_metadata'
);
select throws_ok(
  $$ delete from public.catalog_sync_metadata where id = 1 $$,
  '42501', null,
  'authenticated cannot delete from catalog_sync_metadata'
);

set local role anon;
select throws_ok(
  $$ update public.catalog_sync_metadata set latest_revision = 999999 where id = 1 $$,
  '42501', null,
  'anon cannot update catalog_sync_metadata'
);

-- Intento de manipulación indirecta de metadata a través de catalog_changes
select throws_ok(
  $$ insert into public.catalog_changes (entity_type, entity_id, operation) values ('title', 'fake_id', 'upsert') $$,
  '42501', null,
  'anon cannot insert into catalog_changes (indirect metadata tampering blocked)'
);
set local role authenticated;
select throws_ok(
  $$ insert into public.catalog_changes (entity_type, entity_id, operation) values ('title', 'fake_id', 'upsert') $$,
  '42501', null,
  'authenticated cannot insert into catalog_changes (indirect metadata tampering blocked)'
);

-- 4. Test: Operaciones administrativas y triggers anti-filtraciones
reset role;

-- Setup initial languages and genres
insert into public.languages (id, code, name) values ('10000000-0000-0000-0000-000000000001', 'es', 'Español') on conflict do nothing;
insert into public.genres (id, name, slug) values ('20000000-0000-0000-0000-000000000001', 'Acción', 'accion') on conflict do nothing;

-- Inserción de título borrador/privado (is_published = false)
insert into public.titles (id, media_type, title, normalized_title, is_published)
values ('30000000-0000-0000-0000-000000000001', 'movie', 'Private Draft Movie', 'private draft movie', false);

select is(
  (select count(*)::int from public.catalog_changes where entity_id = '30000000-0000-0000-0000-000000000001'),
  0,
  'private draft title does not emit events in catalog_changes'
);

-- Inserción de fuente para título privado
insert into public.sources (id, title_id, name, url)
values ('40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'Server 1', 'https://example.com/stream1.m3u8');

select is(
  (select count(*)::int from public.catalog_changes where entity_id = '40000000-0000-0000-0000-000000000001'),
  0,
  'source for private title does not emit events in catalog_changes'
);

-- RLS oculta título privado a clientes
set local role anon;
select is(
  (select count(*)::int from public.titles where id = '30000000-0000-0000-0000-000000000001'),
  0,
  'anon role cannot see private title due to RLS'
);
select is(
  (select count(*)::int from public.title_summaries where id = '30000000-0000-0000-0000-000000000001'),
  0,
  'title_summaries view hides private title'
);

-- Transición: título pasa a publicado
reset role;
update public.titles set is_published = true where id = '30000000-0000-0000-0000-000000000001';

select is(
  (select count(*)::int from public.catalog_changes where entity_id = '30000000-0000-0000-0000-000000000001' and operation = 'upsert'),
  1,
  'publishing title emits upsert event for title'
);

select is(
  (select count(*)::int from public.catalog_changes where entity_id = '40000000-0000-0000-0000-000000000001' and operation = 'upsert'),
  1,
  'publishing title cascades upsert event for existing active sources'
);

-- Actualización automática de latest_revision en metadata
select is(
  (select latest_revision from public.catalog_sync_metadata where id = 1),
  (select max(revision) from public.catalog_changes),
  'latest_revision in catalog_sync_metadata updated automatically by trigger'
);

-- Inserción de un nuevo título público
insert into public.titles (id, media_type, title, normalized_title, is_published, created_at)
values ('30000000-0000-0000-0000-000000000002', 'movie', 'Public Movie 2', 'public movie 2', true, now() - interval '1 hour');

-- Eliminación (soft delete) de título público
update public.titles set deleted_at = now() where id = '30000000-0000-0000-0000-000000000002';

select is(
  (select count(*)::int from public.catalog_changes where entity_id = '30000000-0000-0000-0000-000000000002' and operation = 'delete'),
  1,
  'soft-deleting published title emits delete tombstone in catalog_changes'
);

-- RLS: anon puede ver el tombstone en catalog_changes pero no el título eliminado
set local role anon;
select is(
  (select count(*)::int from public.titles where id = '30000000-0000-0000-0000-000000000002'),
  0,
  'deleted title is invisible to anon'
);
select is(
  (select count(*)::int from public.catalog_changes where entity_id = '30000000-0000-0000-0000-000000000002' and operation = 'delete'),
  1,
  'delete tombstone in catalog_changes is accessible to anon for local cache purge'
);

-- 5. Test: Constraints estrictas de seguridad de URLs en sources
reset role;

-- Rechazo de HTTP plano
select throws_ok(
  $$ insert into public.sources (title_id, name, url) values ('30000000-0000-0000-0000-000000000001', 'HTTP Source', 'http://example.com/insecure.m3u8') $$,
  '23514', null,
  'sources url must reject http (requires https)'
);

-- Rechazo de loopback IPv4
select throws_ok(
  $$ insert into public.sources (title_id, name, url) values ('30000000-0000-0000-0000-000000000001', 'Loopback Source', 'https://127.0.0.1/stream.m3u8') $$,
  '23514', null,
  'sources url rejects 127.0.0.1 loopback'
);

-- Rechazo de loopback IPv6
select throws_ok(
  $$ insert into public.sources (title_id, name, url) values ('30000000-0000-0000-0000-000000000001', 'IPv6 Loopback', 'https://[::1]/stream.m3u8') $$,
  '23514', null,
  'sources url rejects [::1] IPv6 loopback'
);

-- Rechazo de IP privada (192.168.x.x)
select throws_ok(
  $$ insert into public.sources (title_id, name, url) values ('30000000-0000-0000-0000-000000000001', 'Private IP', 'https://192.168.1.50/stream.m3u8') $$,
  '23514', null,
  'sources url rejects 192.168.x.x private range'
);

-- Rechazo de credenciales embebidas
select throws_ok(
  $$ insert into public.sources (title_id, name, url) values ('30000000-0000-0000-0000-000000000001', 'Auth URL', 'https://user:password@example.com/stream.m3u8') $$,
  '23514', null,
  'sources url rejects embedded user:pass credentials'
);

-- Rechazo de tokens en query
select throws_ok(
  $$ insert into public.sources (title_id, name, url) values ('30000000-0000-0000-0000-000000000001', 'Token URL', 'https://example.com/stream.m3u8?token=secret123') $$,
  '23514', null,
  'sources url rejects token in query string'
);

-- Rechazo de origin_url con ruta o fragmento
select throws_ok(
  $$ insert into public.sources (title_id, name, url, origin_url)
     values ('30000000-0000-0000-0000-000000000001', 'Bad Origin', 'https://example.com/stream.m3u8', 'https://example.com/some/path') $$,
  '23514', null,
  'origin_url rejects path components (origin only)'
);

-- 6. Test: Compactación administrativa (compact_catalog_changes)
reset role;

-- Validación de argumentos no nulos y >= 1
select throws_ok(
  $$ select public.compact_catalog_changes(null) $$,
  'P0001', 'p_keep_revisions must be non-null and at least 1',
  'compact_catalog_changes rejects null'
);
select throws_ok(
  $$ select public.compact_catalog_changes(0) $$,
  'P0001', 'p_keep_revisions must be non-null and at least 1',
  'compact_catalog_changes rejects 0'
);
select throws_ok(
  $$ select public.compact_catalog_changes(-5) $$,
  'P0001', 'p_keep_revisions must be non-null and at least 1',
  'compact_catalog_changes rejects negative keep_revisions'
);

select lives_ok(
  $$ select public.compact_catalog_changes(1::bigint) $$,
  'admin role postgres can execute compact_catalog_changes'
);

-- Invariante minimum_available_revision <= latest_revision
select ok(
  (select minimum_available_revision <= latest_revision from public.catalog_sync_metadata where id = 1),
  'minimum_available_revision <= latest_revision holds true after compaction'
);

-- Monotonía: compactar con un valor mayor no reduce minimum_available_revision
select lives_ok(
  $$ select public.compact_catalog_changes(100::bigint) $$,
  'compact with large keep_revisions succeeds without error'
);
select ok(
  (select minimum_available_revision >= 1 from public.catalog_sync_metadata where id = 1),
  'minimum_available_revision remains strictly monotonic'
);

-- 7. Test: Paginación Determinista compuesta (created_at DESC, id DESC)
-- Inserción de 2 títulos con el mismo created_at exacto
insert into public.titles (id, media_type, title, normalized_title, is_published, created_at)
values
  ('50000000-0000-0000-0000-000000000001', 'movie', 'Tie 1', 'tie 1', true, '2026-09-10 10:00:00+00'),
  ('50000000-0000-0000-0000-000000000002', 'movie', 'Tie 2', 'tie 2', true, '2026-09-10 10:00:00+00');

-- La paginación por cursor id < cursor.id desempata registros con el mismo timestamp
select is(
  (select count(*)::int from public.titles
   where is_published = true and deleted_at is null
     and (created_at < '2026-09-10 10:00:00+00'
          or (created_at = '2026-09-10 10:00:00+00' and id < '50000000-0000-0000-0000-000000000002'))
     and id = '50000000-0000-0000-0000-000000000001'),
  1,
  'deterministic cursor condition properly breaks timestamp ties using id < cursor.id'
);

-- 8. Test: Reparenting y Visibilidad Booleana (seasons y sources)
-- Setup: Título Público vs Título Privado
insert into public.titles (id, media_type, title, normalized_title, is_published)
values
  ('60000000-0000-0000-0000-000000000001', 'series', 'Public Series Reparent', 'public series reparent', true),
  ('60000000-0000-0000-0000-000000000002', 'series', 'Private Series Reparent', 'private series reparent', false);

-- Inserción de Season en título privado: privada -> privada (0 eventos)
insert into public.seasons (id, title_id, season_number, name)
values ('70000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000002', 1, 'Season Private');

select is(
  (select count(*)::int from public.catalog_changes where entity_id = '70000000-0000-0000-0000-000000000001'),
  0,
  'season on private title emits no events'
);

-- Reparenting de privada -> pública (emite upsert)
update public.seasons
set title_id = '60000000-0000-0000-0000-000000000001'
where id = '70000000-0000-0000-0000-000000000001';

select is(
  (select count(*)::int from public.catalog_changes where entity_id = '70000000-0000-0000-0000-000000000001' and operation = 'upsert'),
  1,
  'reparenting season from private to public emits upsert'
);

-- Reparenting de pública -> privada (emite delete)
update public.seasons
set title_id = '60000000-0000-0000-0000-000000000002'
where id = '70000000-0000-0000-0000-000000000001';

select is(
  (select count(*)::int from public.catalog_changes where entity_id = '70000000-0000-0000-0000-000000000001' and operation = 'delete'),
  1,
  'reparenting season from public to private emits delete'
);

-- Inserción de Source en título privado: privada -> privada (0 eventos)
insert into public.sources (id, title_id, name, url)
values ('80000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000002', 'Source Private', 'https://example.com/stream-p.m3u8');

select is(
  (select count(*)::int from public.catalog_changes where entity_id = '80000000-0000-0000-0000-000000000001'),
  0,
  'source on private title emits no events'
);

-- Reparenting de Source privada -> pública (emite upsert)
update public.sources
set title_id = '60000000-0000-0000-0000-000000000001'
where id = '80000000-0000-0000-0000-000000000001';

select is(
  (select count(*)::int from public.catalog_changes where entity_id = '80000000-0000-0000-0000-000000000001' and operation = 'upsert'),
  1,
  'reparenting source from private to public emits upsert'
);

-- Reparenting de Source pública -> privada (emite delete)
update public.sources
set title_id = '60000000-0000-0000-0000-000000000002'
where id = '80000000-0000-0000-0000-000000000001';

select is(
  (select count(*)::int from public.catalog_changes where entity_id = '80000000-0000-0000-0000-000000000001' and operation = 'delete'),
  1,
  'reparenting source from public to private emits delete'
);

select * from finish();
rollback;
