# Dice Zee — Accounts and Cloud Sync (Phase 1)

**Date:** 2026-09-30
**Status:** Proposed
**Builds on:** [2026-09-10-local-player-profiles-design.md](2026-09-10-local-player-profiles-design.md)

## Goal

Let a player create a full Firebase account (email/password, Google, or Apple)
and have their own finished-match history sync to the cloud, while a fully
offline **guest** mode — today's behaviour — remains available and untouched.
This is Phase 1 of a three-phase roadmap: Phase 2 is friendship, Phase 3 is
online matchups. Only Phase 1 is designed here; later phases get their own
spec once Phase 1 ships.

## Non-goals

- No friend lists, no user search/discovery, no online/real-time matchups —
  Phase 2 and 3.
- No sync of in-progress match state. Only finished `GameResult`s sync; a
  match still must be played to completion on the device it started on.
- No per-seat cloud identity. Only one local `PlayerProfile` per account (the
  one linked as "this is me") has its `PlayerScore`s synced — other seats in a
  hot-seat match stay local-only, exactly as today.
- No change to game rules, `DiceGame`, or scoring.
- No account deletion / data export UI (can be added later; Firebase console
  covers it manually for now).

## Flow

```
MainMenuScreen
  ├─ Account  → AccountScreen
  │     not signed in → sign in / create account (email, Google, Apple)
  │                      or "Continue as Guest" (no-op, closes screen)
  │     signed in      → shows linked PlayerProfile (or picker, if none linked
  │                      yet) + "Sign out"
  ├─ Players     → PlayersScreen (unchanged)
  ├─ Start       → unchanged
  └─ Statistics  → unchanged (StatisticsScreen doesn't know which backend
                    served loadHistory())
```

Guest is the default and requires no interaction — "Continue as Guest" is
just dismissing `AccountScreen` without signing in. Firebase Auth is never
called for a guest; there is no anonymous-auth session.

## Data model

### `lib/models/player_profile.dart` (extend)

Add one nullable field:

- `final bool linkedToAccount;` (default `false`) — true for the single
  profile whose `PlayerScore`s sync to the cloud. At most one profile has this
  set to true at any time; enforced by `AuthService`/`PlayerStorage`
  call sites, not by the model itself.

No change to `toJson`/`fromJson` shape beyond the new key (defaults to
`false` when absent, so old stored profiles keep parsing).

### Firestore shape

```
users/{uid}/matches/{matchId}
```

One document per finished match belonging to the linked profile, with the
same fields as `GameResult.toJson()` (`playedAt`, `playerCount`, `players`)
plus the synced profile's `profileId` at the top level for query convenience.
`matchId` is Firestore's auto-generated document id. No separate `users/{uid}`
summary document — `loadHistory()` queries the subcollection directly,
ordered by `playedAt` descending.

## Storage

### `lib/services/auth_service.dart` (new)

Thin wrapper over `firebase_auth`:

- `Stream<User?> authStateChanges()`
- `Future<void> signUpWithEmail(String email, String password)`
- `Future<void> signInWithEmail(String email, String password)`
- `Future<void> signInWithGoogle()`
- `Future<void> signInWithApple()`
- `Future<void> signOut()`
- `User? get currentUser`

Each sign-in/sign-up method throws a small `AuthFailure` (message only) on
`FirebaseAuthException`, caught and shown inline by `AccountScreen` — no raw
Firebase exceptions reach widget code.

### `lib/services/cloud_game_storage.dart` (new, sibling to `GameStorage`)

Same two-method shape as `GameStorage`, scoped to one `uid` + linked
`profileId`:

- `Future<List<GameResult>> loadHistory()` — query
  `users/{uid}/matches`, ordered by `playedAt` descending, mapped through
  `GameResult.fromJson` (same tolerant `_tryParse` pattern as today).
- `Future<void> saveResult(GameResult result)` — add one document to
  `users/{uid}/matches`. No read-modify-write of the whole list.

### `lib/services/game_storage.dart` (extend — becomes a selector)

- Constructor takes an optional `AuthService`; when
  `authService?.currentUser` is non-null **and** a `PlayerProfile` is linked,
  `loadHistory()`/`saveResult()` delegate to `CloudGameStorage`. Otherwise
  both fall through to the existing `shared_preferences` implementation,
  unchanged.
- Call sites (`GameScreen`, `StatisticsScreen`) don't change — they already
  go through `GameStorage`, injected the same way `PlayerStorage` is today.

### `lib/services/player_storage.dart` (extend)

- `Future<void> linkProfileToAccount(String id)` — sets `linkedToAccount:
  true` on the matching profile and `false` on any other (at most one linked
  profile).
- `Future<void> unlinkProfile()` — clears the flag on whichever profile has
  it, called on sign-out.

### Guest → account migration

On successful `signUpWithEmail`/`signInWithGoogle`/`signInWithApple` when no
profile is linked yet:

1. `AccountScreen` prompts: pick an existing local `PlayerProfile` to link, or
   create a new one.
2. `PlayerStorage.linkProfileToAccount(id)`.
3. Read that profile's existing local matches: `GameStorage.loadHistory()`
   filtered to `PlayerScore.profileId == id`.
4. Upload each as a new `CloudGameStorage` document.
5. If every upload succeeds, no further action — local history is left as-is
   (it's still valid guest-mode data for other profiles/seats, and reads now
   come from the cloud copy going forward for the linked profile). If any
   upload fails, surface "some matches may not have synced" and leave
   everything as it was (no partial-cleanup, nothing to roll back since local
   data is untouched either way).

## Screens

### `lib/widgets/account_screen.dart` (new)

- Not signed in: email/password fields + "Create account" / "Sign in" toggle,
  "Sign in with Google" and "Sign in with Apple" buttons, "Continue as Guest"
  text button that just pops the screen.
- Signed in, no linked profile: prompts to link (existing `PlayerProfile`
  picker, reusing the picker pattern from `PlayerSelectScreen`, or "Create new
  player").
- Signed in, linked: shows the linked profile's name + "Sign out" (calls
  `AuthService.signOut()` then `PlayerStorage.unlinkProfile()`).
- Auth errors render inline under the form (`AuthFailure.message`).

### `main_menu.dart` (extend)

- Add an **Account** `OutlinedButton.icon` next to **Players** /
  **Statistics**, pushing `AccountScreen`.

## Error handling

- Auth errors (bad password, account exists, network down): caught in
  `AuthService`, wrapped as `AuthFailure`, shown inline on `AccountScreen`.
  Never bubble into game/menu flow.
- Firestore write failures during normal play: Firestore's client SDK has
  built-in offline persistence — a `saveResult` while offline queues locally
  and syncs automatically when connectivity returns. No manual retry queue.
- Migration failures: handled per-item as above (step 5); never destructive to
  local data.

## Testing

- `auth_service_test.dart` — using `firebase_auth_mocks`, covering sign
  up/in/out and error mapping to `AuthFailure` (new dev dependency).
- `cloud_game_storage_test.dart` — using `fake_cloud_firestore`, covering
  save/load and ordering (new dev dependency).
- `game_storage_test.dart` — extend with the selector branch (linked vs.
  guest), injecting a fake `AuthService`.
- `player_storage_test.dart` — extend with `linkProfileToAccount` /
  `unlinkProfile`, including the at-most-one-linked invariant.
- `widgets/account_screen_test.dart` (new) — guest-skip path, form
  validation, error display; auth calls mocked.

## Dependencies & project-convention changes

New runtime dependencies: `firebase_core`, `firebase_auth`, `cloud_firestore`,
`google_sign_in`, `sign_in_with_apple`. New dev dependencies:
`firebase_auth_mocks`, `fake_cloud_firestore`.

This breaks the current [CLAUDE.md](../../../CLAUDE.md) rule that
`shared_preferences` is the only dependency — CLAUDE.md's Dependencies and
Persistence sections will be updated alongside this work to describe the
guest-vs-account split and the new packages.

**Ops (outside the Flutter codebase):** Firestore security rules must be
deployed restricting `users/{uid}/matches/**` to reads/writes from that same
authenticated `uid`. Google/Apple sign-in also require one-time provider
configuration in the Firebase console and platform projects (OAuth client for
Google; Sign in with Apple capability + Apple Developer config for iOS).
