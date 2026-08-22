# HourTV Android Profiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the fixed demo profiles with user-created, persistent HourTV profiles and require profile selection at every application start.

**Architecture:** Keep profile persistence, avatar presentation, creation UI, and application routing in separate units. Persist only the minimal `StoredProfile` model in versioned local storage, then derive the existing `UserProfile` runtime shape when a profile becomes active.

**Tech Stack:** React 19, TypeScript 5.8, Tailwind CSS 4, Lucide React, Vite 6, browser behavior QA through the in-app Browser.

**Spec:** `docs/superpowers/specs/2026-08-22-hourtv-android-profiles-search-catalog-design.md`

## Global Constraints

- First launch must require profile creation.
- New full loads must always return to `¿Quién está viendo?` when profiles exist.
- Maximum five profiles; the last remaining profile cannot be deleted.
- Name and avatar are required; name is trimmed and limited to 20 characters.
- Header and Bottom Navigation stay hidden before profile selection.
- Use only local HourTV avatar assets and existing color tokens.
- Preserve the approved Home, Search, Details, TV, Library, Player, and Access layouts.
- Every interactive target is at least 48 px and click focus must not remain visually selected.

---

### Task 1: Versioned profile model and persistence

**Files:**
- Modify: `src/types/index.ts`
- Create: `src/profileStorage.ts`
- Modify: `src/App.tsx`

**Interfaces:**
- Produces: `StoredProfile`, `loadStoredProfiles()`, `saveStoredProfiles(profiles)`, `createStoredProfile(input)`, and `toUserProfile(profile)`.
- Consumes: `INITIAL_USER_PROFILE` as the settings template for the runtime `UserProfile`.

- [ ] **Step 1: Run the failing first-launch behavior test**

Reload the direct preview after clearing `hourtv.profiles.v1` and evaluate:

```js
const text = document.body.innerText || '';
({
  createPrompt: text.includes('Crea tu primer perfil'),
  demoProfilesAbsent: !['Renata', 'Mateo', 'HourTV Kids'].some(name => text.includes(name)),
});
```

Expected before implementation: `createPrompt: false` and at least one demo profile present.

- [ ] **Step 2: Add the persisted type**

```ts
export interface StoredProfile {
  id: string;
  name: string;
  avatarId: string;
  isKidsProfile: boolean;
  createdAt: number;
}
```

- [ ] **Step 3: Implement strict persistence helpers**

Use the exact storage key `hourtv.profiles.v1`. `loadStoredProfiles()` must return `[]` for missing JSON, malformed JSON, non-arrays, invalid fields, or storage exceptions. `saveStoredProfiles()` must store at most five validated profiles.

```ts
export const PROFILE_STORAGE_KEY = 'hourtv.profiles.v1';
export const MAX_PROFILES = 5;

export interface CreateProfileInput {
  name: string;
  avatarId: string;
  isKidsProfile: boolean;
}

export function createStoredProfile(input: CreateProfileInput): StoredProfile {
  const name = input.name.trim().slice(0, 20);
  if (!name || !input.avatarId) throw new Error('PROFILE_REQUIRED_FIELDS');
  return {
    id: crypto.randomUUID(),
    name,
    avatarId: input.avatarId,
    isKidsProfile: input.isKidsProfile,
    createdAt: Date.now(),
  };
}
```

`toUserProfile()` must spread `INITIAL_USER_PROFILE`, replace `id`, `name`, and avatar fields, and enable parental control defaults when `isKidsProfile` is true.

- [ ] **Step 4: Run TypeScript validation and the storage behavior check**

Run the app build in AI Studio and verify that no compilation overlay appears. In the direct preview, create one profile, reload, and confirm `JSON.parse(localStorage.getItem('hourtv.profiles.v1'))` contains exactly one valid record.

- [ ] **Step 5: Save an isolated AI Studio checkpoint**

Save only `src/types/index.ts`, `src/profileStorage.ts`, and the minimal `App.tsx` wiring required for the test.

---

### Task 2: Local HourTV avatar catalog

**Files:**
- Create: `src/assets/profile-avatar-sprite.webp`
- Create: `src/data/profileAvatars.ts`
- Create: `src/components/profiles/ProfileAvatar.tsx`

**Interfaces:**
- Produces: `ProfileAvatarDefinition`, `PROFILE_AVATARS`, and `<ProfileAvatar avatarId size selected />`.
- Consumes: the `avatarId` stored by Task 1.

- [ ] **Step 1: Run the failing avatar-gallery test**

On the create-profile screen, expect at least six buttons whose accessible names begin with `Elegir avatar` and expect no remote image URL.

```js
const avatars = [...document.querySelectorAll('button[aria-label^="Elegir avatar"]')];
({ count: avatars.length, remoteImages: [...document.images].filter(i => /^https?:/.test(i.src)).length });
```

Expected before implementation: `count: 0`.

- [ ] **Step 2: Generate one local cinematic avatar sprite**

Create an eight-cell 4×2 WebP sprite with this prompt: “Eight distinct premium streaming profile portraits, original HourTV cinematic style, diverse ages and appearances, dark backgrounds, emerald highlights, centered head-and-shoulders composition, each portrait isolated in an equal square cell, no logos, no text, no copyrighted characters.” Upload it as `src/assets/profile-avatar-sprite.webp`.

- [ ] **Step 3: Define stable avatar IDs and sprite positions**

```ts
export interface ProfileAvatarDefinition {
  id: string;
  label: string;
  column: 0 | 1 | 2 | 3;
  row: 0 | 1;
}

export const PROFILE_AVATARS: ProfileAvatarDefinition[] = [
  { id: 'aurora', label: 'Aurora', column: 0, row: 0 },
  { id: 'nova', label: 'Nova', column: 1, row: 0 },
  { id: 'atlas', label: 'Atlas', column: 2, row: 0 },
  { id: 'luna', label: 'Luna', column: 3, row: 0 },
  { id: 'orion', label: 'Orión', column: 0, row: 1 },
  { id: 'iris', label: 'Iris', column: 1, row: 1 },
  { id: 'kai', label: 'Kai', column: 2, row: 1 },
  { id: 'sol', label: 'Sol', column: 3, row: 1 },
];
```

- [ ] **Step 4: Implement `ProfileAvatar` with a local sprite crop**

Use `background-size: 400% 200%` and derive `background-position` from the definition. Unknown IDs must fall back to `aurora`. A selected avatar receives a 2 px emerald border and a small check indicator; unselected avatars receive only the subtle HourTV border.

- [ ] **Step 5: Verify and save the avatar checkpoint**

Confirm eight visible avatars, zero remote image URLs, consistent square crops, and 64 px or larger selection targets.

---

### Task 3: First-profile creation and reusable editor

**Files:**
- Create: `src/views/ProfileEditorView.tsx`
- Create: `src/views/ProfileSelectionView.tsx`
- Modify: `src/App.tsx`

**Interfaces:**
- `ProfileEditorView` consumes `initialProfile?: StoredProfile`, `mode: 'create' | 'edit'`, `onSave(input)`, and `onCancel?()`.
- `ProfileSelectionView` consumes `profiles`, `onSelect`, `onAdd`, and `onManage`.

- [ ] **Step 1: Run the failing creation-flow test**

Clear storage and reload. Expect `Crea tu primer perfil`, a name input, eight avatars, an infantil toggle, and a disabled `Crear perfil` button.

- [ ] **Step 2: Implement the editor form**

The form must keep `name`, `avatarId`, and `isKidsProfile` in local state. The primary button is enabled only when `name.trim().length > 0 && avatarId.length > 0`. Submit calls `onSave({ name, avatarId, isKidsProfile })` once.

- [ ] **Step 3: Implement the selector**

Render the stored profiles without an active-state ring. Add `Añadir perfil` while fewer than five profiles exist and a lightweight `Administrar perfiles` action. The component must not render Header or Bottom Navigation.

- [ ] **Step 4: Connect first creation in `App.tsx`**

Replace the current inline fixed-profile selector. Initialize `profiles` with `loadStoredProfiles()`. When empty, render `ProfileEditorView`. After the first save, persist the profile, set it active, and enter Home. When profiles exist but none is active for the current load, render `ProfileSelectionView`.

- [ ] **Step 5: Verify the creation flow**

Test name-only, avatar-only, and valid form states. Create one profile, confirm immediate Home entry and the correct Header avatar, then reload and confirm the selector appears with exactly that profile.

- [ ] **Step 6: Save the creation-flow checkpoint**

Save `ProfileEditorView.tsx`, `ProfileSelectionView.tsx`, and the corresponding `App.tsx` integration.

---

### Task 4: Add, edit, delete, and kids-profile behavior

**Files:**
- Modify: `src/views/ProfileSelectionView.tsx`
- Modify: `src/views/ProfileEditorView.tsx`
- Modify: `src/views/ProfileView.tsx`
- Modify: `src/App.tsx`

**Interfaces:**
- Produces handlers `handleCreateProfile`, `handleUpdateProfile`, `handleDeleteProfile`, and `handleSelectProfile` in `App.tsx`.
- Consumes persistence and avatar interfaces from Tasks 1–3.

- [ ] **Step 1: Run the failing management test**

With one stored profile, expect `Administrar perfiles`; entering management must expose `Editar` but must disable `Eliminar` for the final remaining profile.

- [ ] **Step 2: Implement create and edit handlers**

`handleCreateProfile` rejects a sixth profile. `handleUpdateProfile` replaces only the matching record and preserves `id` and `createdAt`. Both save the complete validated list.

- [ ] **Step 3: Implement deletion safety**

`handleDeleteProfile` returns without mutation when one profile remains. If the deleted ID is active, clear the active profile and return to the selector. Confirm deletion with the existing `ModalSheet`; do not use the browser-native dialog.

- [ ] **Step 4: Connect profile settings**

Replace `PROFILES_LIST` usage in `ProfileView` with the stored profiles passed from `App.tsx`. Preserve existing playback, language, parental-control, and logout settings. A kids profile must retain its parental defaults when activated.

- [ ] **Step 5: Verify limits and state transitions**

Create five profiles and confirm `Añadir perfil` disappears. Edit name/avatar, reload, and confirm persistence. Delete down to one and confirm the final delete action remains disabled.

- [ ] **Step 6: Save the management checkpoint**

Save the four modified files as one coherent checkpoint.

---

### Task 5: Profiles regression and acceptance QA

**Files:**
- Verify only; modify the smallest owning file if a test fails.

**Interfaces:**
- Consumes the complete profile subsystem.
- Produces an evidence table for handoff.

- [ ] **Step 1: Reset storage and verify first run**

Confirm create-first behavior, required fields, eight local avatars, no Header, and no Bottom Navigation.

- [ ] **Step 2: Verify persistence and startup selection**

Create two profiles, reload, confirm both remain, confirm neither is preselected, and select each to verify the Header identity.

- [ ] **Step 3: Verify management and safety**

Edit, add to five, delete back to one, test the kids toggle, and verify the last profile cannot be deleted.

- [ ] **Step 4: Verify protected routes**

Open Home, Search, TV, Details, Library, Player, and Profile. Confirm no visual or navigation regression and no horizontal overflow.

- [ ] **Step 5: Run final build and runtime checks**

Confirm no compile overlay, no console errors, all profile targets at least 48 px, and no remote avatar URL. Leave `¿Quién está viendo?` visible for review.

