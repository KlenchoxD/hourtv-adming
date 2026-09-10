begin;
select plan(13);

-- 1. Setup mock users in auth.users
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, confirmation_token, recovery_token, email_change_token_new, email_change)
values
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'user1@example.com', 'encrypted', now(), now(), now(), '', '', '', ''),
  ('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'user2@example.com', 'encrypted', now(), now(), now(), '', '', '', '')
on conflict (id) do nothing;

-- 2. Test: Anon role permissions (denied)
set local role anon;
set local "request.jwt.claim.sub" to '';
set local "request.jwt.claim.role" to 'anon';

select throws_ok(
  $$ select count(*) from public.account_profiles $$,
  '42501', null,
  'anon role cannot select from account_profiles'
);

select throws_ok(
  $$ insert into public.account_profiles(owner_id, name, avatar_id, is_kids, position)
     values ('11111111-1111-1111-1111-111111111111', 'Anon Profile', 'adult_1', false, 0) $$,
  '42501', null,
  'anon role cannot insert into account_profiles'
);

-- 3. Test: Authenticated User 1 permissions
set local role authenticated;
set local "request.jwt.claim.sub" to '11111111-1111-1111-1111-111111111111';
set local "request.jwt.claim.role" to 'authenticated';

select lives_ok(
  $$ insert into public.account_profiles(owner_id, name, avatar_id, is_kids, position)
     values (auth.uid(), 'User1 Principal', 'adult_1', false, 0) $$,
  'authenticated user 1 creates owned profile'
);

select throws_ok(
  $$ insert into public.account_profiles(owner_id, name, avatar_id, is_kids, position)
     values ('22222222-2222-2222-2222-222222222222', 'Cross User', 'adult_2', false, 1) $$,
  '42501', null,
  'user 1 cannot insert a profile owned by user 2'
);

select is(
  (select count(*)::integer from public.account_profiles),
  1,
  'user 1 sees exactly their 1 owned profile'
);

-- 4. Test: Cross-user isolation with Authenticated User 2
set local role authenticated;
set local "request.jwt.claim.sub" to '22222222-2222-2222-2222-222222222222';
set local "request.jwt.claim.role" to 'authenticated';

select is(
  (select count(*)::integer from public.account_profiles),
  0,
  'user 2 cannot see any profiles owned by user 1'
);

select is(
  (select count(*)::integer from public.account_profiles where owner_id = '11111111-1111-1111-1111-111111111111'),
  0,
  'user 2 filtering by user 1 owner_id returns 0 rows due to RLS'
);

select lives_ok(
  $$ delete from public.account_profiles where owner_id = '11111111-1111-1111-1111-111111111111' $$,
  'user 2 deleting user 1 profile affects 0 rows and does not throw'
);

-- 5. Test: User 1 update, ownership immutability, and 5-profile limit
set local role authenticated;
set local "request.jwt.claim.sub" to '11111111-1111-1111-1111-111111111111';
set local "request.jwt.claim.role" to 'authenticated';

select lives_ok(
  $$ update public.account_profiles set name = 'User1 Renombrado' where position = 0 $$,
  'user 1 can update owned profile name'
);

select throws_ok(
  $$ update public.account_profiles set owner_id = '22222222-2222-2222-2222-222222222222' where position = 0 $$,
  '42501', null,
  'user 1 cannot change profile ownership to another user'
);

-- Insert profiles 2, 3, 4, 5 (total 5)
select lives_ok(
  $$
  insert into public.account_profiles(owner_id, name, avatar_id, is_kids, position) values
    (auth.uid(), 'User1 Dos', 'adult_2', false, 1),
    (auth.uid(), 'User1 Tres', 'adult_3', false, 2),
    (auth.uid(), 'User1 Cuatro', 'kids_1', true, 3),
    (auth.uid(), 'User1 Cinco', 'kids_2', true, 4);
  $$,
  'user 1 can insert up to 5 profiles total'
);

-- Attempt 6th insert (must fail with 23514 / profile_limit_exceeded)
select throws_ok(
  $$ insert into public.account_profiles(owner_id, name, avatar_id, is_kids, position)
     values (auth.uid(), 'User1 Sexto', 'adult_4', false, 4) $$,
  '23514', 'profile_limit_exceeded',
  'sixth profile insertion is rejected by enforce_account_profile_limit trigger'
);

-- 6. Test: Delete owned profile
select lives_ok(
  $$ delete from public.account_profiles where position = 0 $$,
  'user 1 can delete owned profile'
);

select * from finish();
rollback;
