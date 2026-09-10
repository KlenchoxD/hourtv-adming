# HourTV Supabase Authentication and Profiles Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add secure optional Supabase email/password authentication, verified-email enforcement, Guest access, and up to five cloud-backed profiles per account without changing HourTV's catalog or playback data paths yet.

**Architecture:** Introduce an auth boundary in front of the existing profile gate and hide Supabase behind injectable gateways so widget tests never require the network. Signed-in users read and mutate only their own `account_profiles` rows through RLS; Guest continues using the existing local `StorageService`. Phase 2 stores only account/profile identity and a local migration intent—favorites, progress, catalog pagination, recommendations, and ServerHunter dual-write remain later phases.

**Tech Stack:** Flutter/Dart 3.12, `supabase_flutter: 2.17.2`, Supabase Auth, PostgreSQL 15+, Row Level Security, Supabase CLI, Flutter widget tests, pgTAP database tests.

**Spec:** `docs/superpowers/specs/2026-09-09-hourtv-supabase-catalog-sync-performance-design.md`

## Global Constraints

- Do not change `1.1.14+16` or replace public release `v1.1.14`.
- Use email/password only; do not add Google, Apple, phone, anonymous Supabase Auth, or social login.
- Supabase **Confirm email** must remain enabled. An unverified account cannot enter the signed-in profile area.
- Preserve fully functional local Guest mode and all existing Guest data.
- Allow at most five profiles per authenticated account; enforce this in PostgreSQL and in the UI.
- Do not upload favorites, playback progress, recent searches, watch counts, PINs, passwords, catalog data, or recommendations in this phase.
- Never include a secret key or `service_role` key in Flutter, Git, assets, logs, tests, APKs, or screenshots.
- Initialize with a project URL and client-safe publishable key supplied through `--dart-define-from-file`; do not commit the values.
- Enable RLS and explicit least-privilege grants on every exposed table. Policies must include ownership checks using `(select auth.uid())`.
- Do not authorize from `user_metadata`; profile ownership comes from `auth.uid()` and database columns.
- Every `UPDATE` policy requires both a matching `SELECT` policy and `USING` plus `WITH CHECK`.
- Do not use `SECURITY DEFINER` in `public`. The five-profile limit is a row trigger that does not bypass RLS.
- Work by TDD. Stage exact files only; never use `git add .` or `git add -A`.
- Stop after Task 8. Do not begin catalog migration, cross-device progress/favorites, Guest data upload, or recommendations.

---

### Task 1: Reproducible Supabase tooling and client configuration

**Files:**
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Modify: `.gitignore`
- Create: `config/supabase.example.json`
- Create: `lib/services/supabase_config.dart`
- Create: `test/supabase_config_test.dart`

**Interfaces:**
- Produces: `SupabaseConfig.fromEnvironment()`, `SupabaseConfig.isConfigured`, `SupabaseConfig.projectUrl`, `SupabaseConfig.publishableKey`.
- Consumes later: `SupabaseBootstrap.initialize(SupabaseConfig)` in Task 2.

- [ ] **Step 1: Add failing configuration tests**

Test a pure constructor/parser, not real process environment mutation:

```dart
test('configured requires an https URL and publishable key', () {
  expect(SupabaseConfig.parse(url: '', publishableKey: '').isConfigured, isFalse);
  expect(
    SupabaseConfig.parse(
      url: 'https://project.supabase.co',
      publishableKey: 'sb_publishable_test',
    ).isConfigured,
    isTrue,
  );
});

test('secret-looking keys are rejected from the client', () {
  expect(
    () => SupabaseConfig.parse(
      url: 'https://project.supabase.co',
      publishableKey: 'service_role.secret',
    ),
    throwsArgumentError,
  );
});
```

- [ ] **Step 2: Run the test and verify failure**

Run: `flutter test test/supabase_config_test.dart`

Expected: FAIL because `SupabaseConfig` does not exist.

- [ ] **Step 3: Add pinned dependency and safe build-time configuration**

Add exact dependency `supabase_flutter: 2.17.2` and run `flutter pub get`. Implement:

```dart
final class SupabaseConfig {
  const SupabaseConfig._(this.projectUrl, this.publishableKey);

  final String projectUrl;
  final String publishableKey;
  bool get isConfigured => projectUrl.isNotEmpty && publishableKey.isNotEmpty;

  factory SupabaseConfig.fromEnvironment() => SupabaseConfig.parse(
        url: const String.fromEnvironment('SUPABASE_URL'),
        publishableKey:
            const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
      );

  factory SupabaseConfig.parse({
    required String url,
    required String publishableKey,
  }) {
    final uri = Uri.tryParse(url.trim());
    final key = publishableKey.trim();
    if (key.toLowerCase().contains('service_role') ||
        key.toLowerCase().startsWith('sb_secret_')) {
      throw ArgumentError('La APK solo acepta una clave publicable.');
    }
    if (url.trim().isEmpty && key.isEmpty) return const SupabaseConfig._('', '');
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || key.isEmpty) {
      throw ArgumentError('Configuración de Supabase incompleta.');
    }
    return SupabaseConfig._(uri.toString(), key);
  }
}
```

Create `config/supabase.example.json` with empty values and ignore `config/supabase.local.json`:

```json
{
  "SUPABASE_URL": "https://project-ref.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_example-not-a-real-key"
}
```

- [ ] **Step 4: Verify package and tests**

Run:

```powershell
flutter pub get
flutter test test/supabase_config_test.dart
flutter pub deps | Select-String supabase_flutter
```

Expected: tests pass and dependency resolves to `2.17.2`; `pubspec.lock` is updated.

- [ ] **Step 5: Commit Task 1**

```powershell
git add pubspec.yaml pubspec.lock .gitignore config/supabase.example.json lib/services/supabase_config.dart test/supabase_config_test.dart
git diff --cached --check
git commit -m "build(auth): configurar cliente Supabase de forma segura"
```

### Task 2: Optional Supabase bootstrap and injectable auth boundary

**Files:**
- Create: `lib/services/supabase_bootstrap.dart`
- Create: `lib/services/auth/auth_gateway.dart`
- Create: `lib/services/auth/supabase_auth_gateway.dart`
- Create: `lib/services/auth/unavailable_auth_gateway.dart`
- Modify: `lib/main.dart`
- Create: `test/supabase_bootstrap_test.dart`
- Create: `test/auth_gateway_test.dart`

**Interfaces:**
- Produces: `AuthUser`, `AuthSessionState`, `AuthGateway`, `SupabaseBootstrap.initialize`, `SupabaseBootstrap.authGateway`.
- `AuthGateway` methods: `signUp`, `signIn`, `refreshSession`, `resendVerification`, `resetPassword`, `signOut`; stream `states`; getter `currentState`.
- Guest mode never calls Supabase.

- [ ] **Step 1: Write failing gateway and bootstrap tests**

```dart
test('missing config keeps Guest mode available without initializing Supabase', () async {
  final bootstrap = SupabaseBootstrap.forTest();
  await bootstrap.initialize(SupabaseConfig.parse(url: '', publishableKey: ''));
  expect(bootstrap.isAvailable, isFalse);
  expect(bootstrap.authGateway, isA<UnavailableAuthGateway>());
});

test('unavailable gateway never accepts cloud login', () async {
  final gateway = UnavailableAuthGateway();
  await expectLater(
    gateway.signIn(email: 'user@example.com', password: 'Password123!'),
    throwsA(isA<AuthUnavailableException>()),
  );
});
```

- [ ] **Step 2: Run and verify failure**

Run: `flutter test test/supabase_bootstrap_test.dart test/auth_gateway_test.dart`

Expected: FAIL because the boundary types do not exist.

- [ ] **Step 3: Implement the boundary**

Define stable app-owned types:

```dart
enum AuthSessionPhase { guest, signedOut, verificationRequired, authenticated }

final class AuthUser {
  const AuthUser({required this.id, required this.email, required this.emailVerified});
  final String id;
  final String email;
  final bool emailVerified;
}

final class AuthSessionState {
  const AuthSessionState(this.phase, {this.user});
  final AuthSessionPhase phase;
  final AuthUser? user;
}

abstract interface class AuthGateway {
  AuthSessionState get currentState;
  Stream<AuthSessionState> get states;
  Future<AuthSessionState> signUp({required String email, required String password});
  Future<AuthSessionState> signIn({required String email, required String password});
  Future<AuthSessionState> refreshSession();
  Future<void> resendVerification(String email);
  Future<void> resetPassword(String email);
  Future<void> signOut();
}
```

`SupabaseAuthGateway` maps `onAuthStateChange`, `currentSession`, `signUp`, `signInWithPassword`, `refreshSession`, `resend(type: OtpType.signup)`, `resetPasswordForEmail`, and `signOut()` into those types. Registration and password-reset email calls use `emailRedirectTo: 'hourtv://auth-callback'`. A user with `emailConfirmedAt == null` maps to `verificationRequired`, never `authenticated`.

Initialize Supabase only when configured:

```dart
await Supabase.initialize(
  url: config.projectUrl,
  publishableKey: config.publishableKey,
);
```

Call bootstrap after `StorageService.init()` and before `runApp()`. Initialization failure must be logged without the key and must leave Guest mode usable.

- [ ] **Step 4: Verify isolated behavior and startup regression**

Run:

```powershell
flutter test test/supabase_bootstrap_test.dart test/auth_gateway_test.dart
flutter test test/startup_readiness_test.dart test/home_loading_state_test.dart
```

Expected: all pass; no network is required.

- [ ] **Step 5: Commit Task 2**

```powershell
git add lib/main.dart lib/services/supabase_bootstrap.dart lib/services/auth/auth_gateway.dart lib/services/auth/supabase_auth_gateway.dart lib/services/auth/unavailable_auth_gateway.dart test/supabase_bootstrap_test.dart test/auth_gateway_test.dart
git diff --cached --check
git commit -m "feat(auth): aislar sesiones Supabase del modo invitado"
```

### Task 3: Profile schema, five-profile database invariant, grants and RLS

**Files:**
- Create through CLI: the timestamped `create_account_profiles.sql` file printed by `supabase migration new create_account_profiles` inside `supabase/migrations/`
- Create: `supabase/tests/account_profiles_rls.test.sql`
- Create: `supabase/seed.sql`
- Modify if generated: `supabase/config.toml`

**Interfaces:**
- Produces table: `public.account_profiles(id uuid, owner_id uuid, name text, avatar_id text, is_kids boolean, position smallint, created_at timestamptz, updated_at timestamptz)`.
- Ownership: `owner_id = auth.uid()`.
- Maximum: five rows per `owner_id`, enforced for INSERT and owner-changing UPDATE.
- Client grants: authenticated can select/insert/update/delete; anon gets none.

- [ ] **Step 1: Discover and initialize the installed CLI**

Run:

```powershell
supabase --version
supabase --help
if (-not (Test-Path supabase\config.toml)) { supabase init }
supabase migration new create_account_profiles
```

Expected: a CLI-generated migration filename. Do not invent or rename its timestamp.

- [ ] **Step 2: Write failing pgTAP policy tests first**

The test transaction creates two auth users, sets request JWT claims for each, then asserts:

```sql
select lives_ok(
  $$ insert into public.account_profiles(owner_id, name, avatar_id, is_kids, position)
     values (auth.uid(), 'Principal', 'adult_1', false, 0) $$,
  'an authenticated user creates an owned profile'
);

select throws_ok(
  $$ insert into public.account_profiles(owner_id, name, avatar_id, is_kids, position)
     values ('00000000-0000-0000-0000-000000000002', 'Ajeno', 'adult_2', false, 1) $$,
  '42501', null,
  'a user cannot insert another owner profile'
);

select is(
  (select count(*)::integer from public.account_profiles),
  1,
  'a user sees only owned profiles'
);
```

Add explicit assertions for SELECT, INSERT, UPDATE, DELETE, anon denial, cross-user denial, exactly five successful inserts, sixth insert rejected, and UPDATE cannot move ownership.

- [ ] **Step 3: Run tests to verify schema is absent**

Run: `supabase test db`

Expected: FAIL because `public.account_profiles` does not exist.

- [ ] **Step 4: Implement schema, constraints, trigger, RLS and grants**

The generated migration must contain:

```sql
create table public.account_profiles (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 32),
  avatar_id text not null check (char_length(btrim(avatar_id)) between 1 and 64),
  is_kids boolean not null default false,
  position smallint not null check (position between 0 and 4),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, position)
);

create index account_profiles_owner_id_idx
  on public.account_profiles(owner_id);

alter table public.account_profiles enable row level security;
revoke all on table public.account_profiles from anon, authenticated;
grant select, insert, update, delete on table public.account_profiles to authenticated;

create policy "account_profiles_select_owned"
on public.account_profiles for select to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = owner_id);

create policy "account_profiles_insert_owned"
on public.account_profiles for insert to authenticated
with check ((select auth.uid()) is not null and (select auth.uid()) = owner_id);

create policy "account_profiles_update_owned"
on public.account_profiles for update to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = owner_id)
with check ((select auth.uid()) is not null and (select auth.uid()) = owner_id);

create policy "account_profiles_delete_owned"
on public.account_profiles for delete to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = owner_id);

create function public.enforce_account_profile_limit()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  existing_count integer;
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(new.owner_id::text, 0)
  );
  select count(*) into existing_count
  from public.account_profiles
  where owner_id = new.owner_id;
  if existing_count >= 5 then
    raise exception using
      errcode = '23514',
      message = 'profile_limit_exceeded';
  end if;
  return new;
end;
$$;

revoke all on function public.enforce_account_profile_limit() from public;

create trigger account_profiles_limit_before_insert
before insert on public.account_profiles
for each row execute function public.enforce_account_profile_limit();

create function public.touch_account_profile_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = pg_catalog.now();
  return new;
end;
$$;

revoke all on function public.touch_account_profile_updated_at() from public;

create trigger account_profiles_touch_before_update
before update on public.account_profiles
for each row execute function public.touch_account_profile_updated_at();
```

Add a `before insert` trigger function with default invoker security. It calls `pg_advisory_xact_lock(hashtextextended(new.owner_id::text, 0))`, counts that owner's existing rows in `public.account_profiles`, and raises SQLSTATE `23514` with `profile_limit_exceeded` when the count is already five. This serializes concurrent profile creation without reading `auth.users` and without bypassing RLS. Add a separate ordinary `before update` timestamp trigger. Ownership-changing UPDATE remains impossible through the `USING`/`WITH CHECK` policy. Do not grant anon access and do not create a public view.

- [ ] **Step 5: Verify database security**

Run:

```powershell
supabase db reset
supabase test db
supabase db advisors
supabase migration list --local
```

Expected: all policy tests pass; no security advisor finding for exposed unprotected tables or functions. If `db advisors` is unavailable, record CLI version and use Supabase MCP `get_advisors` during execution.

- [ ] **Step 6: Commit Task 3**

Stage only the CLI-generated migration and exact Supabase files:

```powershell
$migration = Get-ChildItem -LiteralPath supabase\migrations -Filter '*_create_account_profiles.sql' | Select-Object -Single
git add supabase/config.toml supabase/seed.sql $migration.FullName supabase/tests/account_profiles_rls.test.sql
git diff --cached --check
git commit -m "feat(database): proteger perfiles de cuenta con RLS"
```

The `Select-Object -Single` guard must fail if zero or multiple matching migrations exist; resolve that before staging.

### Task 4: Auth access screen and verified-email flow

**Files:**
- Create: `lib/new_ui/hourtv_auth_gate.dart`
- Create: `lib/new_ui/hourtv_auth_page.dart`
- Create: `lib/new_ui/hourtv_verify_email_page.dart`
- Create: `lib/services/auth/auth_controller.dart`
- Modify: `lib/main.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Create: `test/auth_gate_test.dart`
- Create: `test/auth_page_test.dart`

**Interfaces:**
- Produces: `AuthController`, `HourTvAuthGate`, `HourTvAuthPage`, `HourTvVerifyEmailPage`.
- Routing states: Guest -> existing app/profile gate; signedOut -> access page; verificationRequired -> verification page; authenticated -> cloud profile gate.
- Inputs: injected `AuthGateway`, `Widget guestChild`, `Widget authenticatedChild`.

- [ ] **Step 1: Write failing widget tests**

```dart
testWidgets('access screen preserves explicit Guest entry', (tester) async {
  final gateway = FakeAuthGateway.signedOut();
  await tester.pumpWidget(testApp(HourTvAuthGate(
    gateway: gateway,
    guestChild: const Text('GUEST_APP'),
    authenticatedChild: const Text('CLOUD_PROFILES'),
  )));
  expect(find.text('Continuar como invitado'), findsOneWidget);
  await tester.tap(find.text('Continuar como invitado'));
  await tester.pump();
  expect(find.text('GUEST_APP'), findsOneWidget);
});

testWidgets('unverified email cannot enter cloud profiles', (tester) async {
  final gateway = FakeAuthGateway.verificationRequired('user@example.com');
  await tester.pumpWidget(testAuthGate(gateway));
  expect(find.text('VERIFICA TU CORREO'), findsOneWidget);
  expect(find.text('CLOUD_PROFILES'), findsNothing);
});
```

Cover valid email, password minimum 8 characters, loading-state button disabling, friendly mapped errors, resend cooldown, reset-password request, sign-out, and auth-stream transition after email verification.

- [ ] **Step 2: Run and verify failure**

Run: `flutter test test/auth_gate_test.dart test/auth_page_test.dart`

Expected: FAIL because auth UI does not exist.

- [ ] **Step 3: Implement access UI and controller**

Use the established black/emerald HourTV design. The first screen exposes exactly:

- `INICIAR SESIÓN`
- `CREAR CUENTA`
- `Continuar como invitado`

Registration calls `signUp`; when Confirm email is active, `session == null` must lead to `HourTvVerifyEmailPage`. That page displays the destination email, `Reenviar correo`, `Ya verifiqué mi correo`, and `Usar modo invitado`. `Ya verifiqué mi correo` calls `refreshSession()` and enters cloud profiles only when the refreshed user has `emailConfirmedAt != null`. Do not reveal whether an account exists beyond Supabase's safe response. Map network, invalid credentials, weak password, rate-limit, and unavailable-config errors to Spanish messages without exception dumps.

Add an Android intent filter for scheme `hourtv` and host `auth-callback` to the existing main activity. Keep the existing package/application ID unchanged. Register exactly `hourtv://auth-callback` in the development project's Auth redirect URLs.

Wrap the existing `_AppShell` using this order:

```text
HourTvStartupCover
  -> HourTvAuthGate
       -> Guest: existing HourTvProfileGate + local storage
       -> Authenticated: HourTvCloudProfileGate (Task 6)
```

- [ ] **Step 4: Verify UI and existing Guest regression**

Run:

```powershell
flutter test test/auth_gate_test.dart test/auth_page_test.dart
flutter test test/profile_gate_test.dart test/hourtv_profile_navigation_crash_test.dart
```

Expected: all pass and Guest remains available with no Supabase config.

- [ ] **Step 5: Commit Task 4**

```powershell
git add android/app/src/main/AndroidManifest.xml lib/main.dart lib/services/auth/auth_controller.dart lib/new_ui/hourtv_auth_gate.dart lib/new_ui/hourtv_auth_page.dart lib/new_ui/hourtv_verify_email_page.dart test/auth_gate_test.dart test/auth_page_test.dart
git diff --cached --check
git commit -m "feat(auth): añadir acceso por correo y modo invitado"
```

### Task 5: Cloud profile model and repository

**Files:**
- Create: `lib/models/hourtv_account_profile.dart`
- Create: `lib/services/profiles/profile_repository.dart`
- Create: `lib/services/profiles/supabase_profile_repository.dart`
- Create: `lib/services/profiles/local_guest_profile_repository.dart`
- Create: `test/account_profile_test.dart`
- Create: `test/profile_repository_test.dart`

**Interfaces:**
- Produces: immutable `HourTvAccountProfile`; `ProfileRepository.list/create/update/delete`.
- `SupabaseProfileRepository` writes `owner_id` from the authenticated user, never from UI input.
- `LocalGuestProfileRepository` adapts existing `StorageService` without changing stored Guest records.

- [ ] **Step 1: Write failing repository contract tests**

```dart
test('profile model round-trips database rows', () {
  final profile = HourTvAccountProfile.fromJson(profileRow);
  expect(profile.ownerId, ownerId);
  expect(profile.position, 0);
  expect(profile.toInsertJson(), isNot(contains('id')));
});

test('repository translates database profile limit violation', () async {
  final api = FakeProfilesApi.throwing(code: '23514', message: 'profile_limit_exceeded');
  final repository = SupabaseProfileRepository(api: api, currentUserId: () => ownerId);
  await expectLater(repository.create(draft), throwsA(isA<ProfileLimitException>()));
});
```

Also assert deterministic order by `position`, no sixth local profile, trims name, preserves `isKids`, and refuses cloud operations without an authenticated user.

- [ ] **Step 2: Run and verify failure**

Run: `flutter test test/account_profile_test.dart test/profile_repository_test.dart`

Expected: FAIL because model and repositories do not exist.

- [ ] **Step 3: Implement model and repositories**

Use this interface:

```dart
abstract interface class ProfileRepository {
  Future<List<HourTvAccountProfile>> list();
  Future<HourTvAccountProfile> create(ProfileDraft draft);
  Future<HourTvAccountProfile> update(HourTvAccountProfile profile);
  Future<void> delete(String profileId);
}
```

Cloud queries must always filter by owner even though RLS also protects them:

```dart
await client
  .from('account_profiles')
  .select()
  .eq('owner_id', userId)
  .order('position');
```

Never cache passwords or access tokens manually. Supabase owns session persistence.

- [ ] **Step 4: Run contract and storage regression tests**

Run:

```powershell
flutter test test/account_profile_test.dart test/profile_repository_test.dart
flutter test test/profile_gate_test.dart test/storage_cache_test.dart
```

Expected: all pass.

- [ ] **Step 5: Commit Task 5**

```powershell
git add lib/models/hourtv_account_profile.dart lib/services/profiles/profile_repository.dart lib/services/profiles/supabase_profile_repository.dart lib/services/profiles/local_guest_profile_repository.dart test/account_profile_test.dart test/profile_repository_test.dart
git diff --cached --check
git commit -m "feat(profiles): añadir repositorios local y Supabase"
```

### Task 6: Authenticated five-profile gate

**Files:**
- Create: `lib/new_ui/hourtv_cloud_profile_gate.dart`
- Modify: `lib/new_ui/hourtv_profile_gate.dart`
- Modify: `lib/new_ui/hourtv_profile_page.dart`
- Modify: `lib/main.dart`
- Create: `test/cloud_profile_gate_test.dart`
- Modify: `test/profile_gate_test.dart`

**Interfaces:**
- Produces: `HourTvCloudProfileGate(repository, onProfileSelected)`.
- Reuses existing avatar catalog, profile type, Kids PIN behavior and visual cards.
- Cloud profile selection sets a stable UUID-based active profile namespace locally; it does not sync per-profile content data yet.

- [ ] **Step 1: Write failing cloud-profile widget tests**

```dart
testWidgets('fifth cloud profile removes add action', (tester) async {
  final repository = FakeProfileRepository.withCount(5);
  await tester.pumpWidget(testApp(HourTvCloudProfileGate(repository: repository)));
  await tester.pumpAndSettle();
  expect(find.text('AGREGAR PERFIL'), findsNothing);
  expect(find.text('Máximo de 5 perfiles'), findsOneWidget);
});

testWidgets('repository failure offers retry and sign out', (tester) async {
  final repository = FakeProfileRepository.failing();
  await tester.pumpWidget(testApp(HourTvCloudProfileGate(repository: repository)));
  await tester.pumpAndSettle();
  expect(find.text('Reintentar'), findsOneWidget);
  expect(find.text('Cerrar sesión'), findsOneWidget);
});
```

Cover empty account, create, select, rename, delete confirmation, Kids PIN, loading skeleton, ownership-safe errors, and account switch clearing active cloud profile selection.

- [ ] **Step 2: Run and verify failure**

Run: `flutter test test/cloud_profile_gate_test.dart test/profile_gate_test.dart`

Expected: FAIL because cloud gate does not exist.

- [ ] **Step 3: Implement cloud gate while extracting reusable presentation**

Extract only the shared avatar/type/name widgets needed by both gates; do not rewrite unrelated profile UI. On selection, persist:

```dart
await StorageService.setCloudProfileContext(
  accountId: authenticatedUser.id,
  profileId: selected.id,
  name: selected.name,
  avatarId: selected.avatarId,
  isKids: selected.isKids,
);
```

Add `clearCloudProfileContext()` on sign-out. Namespace remains based on the cloud profile UUID so later sync can map local data correctly. The add action is disabled at five, but the database remains the authoritative enforcement.

- [ ] **Step 4: Verify gates and navigation**

Run:

```powershell
flutter test test/cloud_profile_gate_test.dart test/profile_gate_test.dart
flutter test test/hourtv_profile_navigation_crash_test.dart test/kids_profile_auto_restrict_test.dart
```

Expected: all pass.

- [ ] **Step 5: Commit Task 6**

```powershell
git add lib/main.dart lib/new_ui/hourtv_cloud_profile_gate.dart lib/new_ui/hourtv_profile_gate.dart lib/new_ui/hourtv_profile_page.dart lib/services/storage_service.dart test/cloud_profile_gate_test.dart test/profile_gate_test.dart
git diff --cached --check
git commit -m "feat(profiles): integrar hasta cinco perfiles por cuenta"
```

### Task 7: Guest-to-account migration intent without uploading private data

**Files:**
- Create: `lib/services/migration/guest_migration_service.dart`
- Create: `lib/new_ui/hourtv_guest_import_prompt.dart`
- Modify: `lib/new_ui/hourtv_cloud_profile_gate.dart`
- Create: `test/guest_migration_service_test.dart`
- Create: `test/guest_import_prompt_test.dart`

**Interfaces:**
- Produces: `GuestMigrationSummary`, `GuestMigrationDecision`, `GuestMigrationService.inspect/rememberDecision`.
- Phase 2 records only a local choice: `pending`, `declined`, or `acceptedForPhase3` for `(accountId, localGuestProfileId)`.
- No favorite/progress/recent/watch-count payload leaves the device.

- [ ] **Step 1: Write failing privacy-boundary tests**

```dart
test('inspection reports counts but does not expose content payloads', () async {
  final summary = await service.inspect(localProfileId: 'invitado');
  expect(summary.favoriteCount, 2);
  expect(summary.progressCount, 3);
  expect(summary.toJson().keys, unorderedEquals([
    'localProfileId', 'favoriteCount', 'progressCount', 'recentCount'
  ]));
});

test('acceptance remains local for Phase 3', () async {
  await service.rememberDecision(accountId, GuestMigrationDecision.acceptedForPhase3);
  expect(fakeRemoteApi.calls, isEmpty);
});
```

- [ ] **Step 2: Run and verify failure**

Run: `flutter test test/guest_migration_service_test.dart test/guest_import_prompt_test.dart`

Expected: FAIL because migration boundary does not exist.

- [ ] **Step 3: Implement one-time prompt and local decision**

After the first verified sign-in, if Guest has meaningful data, show:

```text
Encontramos datos del modo invitado
2 favoritos y progreso en 3 títulos podrán vincularse a este perfil
cuando se active la sincronización.

[Conservar para importar] [Ahora no]
```

Do not say the data was synchronized. Do not delete Guest data. Store the decision under an account-scoped local key and never display the prompt repeatedly after a decision.

- [ ] **Step 4: Verify privacy and UI**

Run:

```powershell
flutter test test/guest_migration_service_test.dart test/guest_import_prompt_test.dart
flutter test test/auth_gate_test.dart test/cloud_profile_gate_test.dart
```

Expected: all pass and fake remote call count remains zero.

- [ ] **Step 5: Commit Task 7**

```powershell
git add lib/services/migration/guest_migration_service.dart lib/new_ui/hourtv_guest_import_prompt.dart lib/new_ui/hourtv_cloud_profile_gate.dart test/guest_migration_service_test.dart test/guest_import_prompt_test.dart
git diff --cached --check
git commit -m "feat(migration): preparar importación segura del invitado"
```

### Task 8: End-to-end verification and Supabase handoff

**Files:**
- Create: `docs/verification/hourtv-supabase-auth-profiles-phase-2.md`
- Modify only if necessary: `README.md`

**Interfaces:**
- Verifies Tasks 1-7 as one system.
- Produces exact configuration instructions for local development and the later signed release.

- [ ] **Step 1: Run complete local verification**

```powershell
flutter pub get
flutter test
flutter analyze
git diff --check
```

Expected: all tests pass, analyzer reports no issues, diff check exits 0.

- [ ] **Step 2: Run database verification**

```powershell
supabase db reset
supabase test db
supabase db advisors
supabase migration list --local
```

Expected: RLS allow/deny matrix passes; no unprotected exposed object. Record exact CLI version and outputs.

- [ ] **Step 3: Validate against a development Supabase project**

Before this step, obtain only `SUPABASE_URL` and the client-safe publishable key from the project Connect panel. Enable Confirm email and add HourTV's callback URI to Auth redirect URLs. Create ignored `config/supabase.local.json`, then run:

```powershell
flutter run --dart-define-from-file=config/supabase.local.json
```

Exercise: Guest entry, register, blocked-unverified state, resend, verify via email, sign in, create five profiles, sixth rejected, cross-account isolation, rename/delete, sign out, and offline Guest fallback. Never paste secrets into logs or documentation.

- [ ] **Step 4: Inspect APK for forbidden secrets**

Build an internal debug APK with the development publishable key only. Inspect extracted strings for `service_role`, `sb_secret_`, database passwords and access tokens. Expected: none. A publishable key is expected and safe only because RLS tests passed.

- [ ] **Step 5: Document evidence and phase boundary**

Record test counts, Supabase CLI version, migration filename, RLS matrix, advisor result, devices tested, and unresolved external setup. State explicitly:

- No public release/version bump was performed.
- Guest data was not uploaded.
- Favorites/progress/catalog/recommendations were not migrated.
- Phase 3 must implement catalog pagination/local indexed cache before mass catalog ingestion.

- [ ] **Step 6: Commit Task 8**

```powershell
git add docs/verification/hourtv-supabase-auth-profiles-phase-2.md README.md
git diff --cached --check
git commit -m "test(auth): documentar seguridad y perfiles Supabase"
```

If `README.md` did not require a change, omit it from `git add`.

## Phase Boundary

Stop after Task 8 for review. Do not push, tag, change the public version, build a release APK, or create a GitHub Release unless the user separately authorizes release deployment.

Later plans, in order:

1. Phase 3: paginated Supabase catalog, indexed local database, delta refresh, image strategy, and JSON emergency fallback.
2. Phase 4: per-profile favorites/progress synchronization, conflict resolution, actual Guest import, offline outbox, and personalized recommendations.
3. Phase 5: HourTV Admin and ServerHunter dual-write, catalog backfill, cutover monitoring, and JSON retirement criteria.
