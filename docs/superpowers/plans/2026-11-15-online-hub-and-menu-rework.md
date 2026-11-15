# Online Hub and Menu Rework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put online play on the main menu behind one Online hub (matches + new game + friends), and remove the manual local-player system.

**Architecture:** `MainMenuScreen` gains an Online button that opens a new `OnlineHubScreen` (auth gate around the existing `OnlineMatchesScreen`, which gets a New game action and a Friends action). The local `PlayerStorage` shrinks to the account profile only; offline seats are guests unless seat 1 is the signed-in account. Cloud sync of the players list is removed; games sync stays.

**Tech Stack:** Flutter, `shared_preferences`, existing Firestore-backed services. No new packages (CLAUDE.md: ask first).

**Spec:** [docs/superpowers/specs/2026-11-15-online-hub-and-menu-rework-design.md](../specs/2026-11-15-online-hub-and-menu-rework-design.md)

## Global Constraints

- No new dependencies; plain `StatefulWidget` + `setState`, `Navigator.push(MaterialPageRoute)`.
- Pure logic in `models/`/`services/` (no `package:flutter`); tests first; `flutter analyze` clean after every task.
- Main menu stays Firebase-free until Online/Account is tapped (auth built lazily via `authServiceBuilder`).
- No online-match preview or badge on the main menu.
- Menu order: Play · Online · Statistics · Account. No "Players".
- Firestore layout/rules unchanged.

## Review Focus

- Signed-out user taps Online → sees "Sign in" prompt, no Firebase stream opened, no crash.
- User with zero friends taps New game → friend picker explains and offers Friends, not an empty dialog.
- Old history entries whose `profileId` points at a removed manual profile still load; they count under "Everyone" only.
- Existing stored `dice_zee.players` containing non-account profiles: they're ignored by Play and Statistics (no crash, no Player-select screen).
- User signs out while the hub is open → hub switches to the sign-in prompt.

---

### Task 1: Play menu starts directly with the account/guest lineup

**Files:**
- Modify: `lib/widgets/play_menu_screen.dart`
- Delete: `lib/widgets/player_select_screen.dart`, `test/widgets/player_select_screen_test.dart`
- Test: `test/widgets/play_menu_screen_test.dart`

**Interfaces:**
- Consumes: `PlayerStorage.loadProfiles()`, `PlayerProfile.linkedToAccount`, `GameScreen(lineup: List<PlayerProfile?>, mode: GameMode)`.
- Produces: `PlayMenuScreen._start()` always pushes `GameScreen` with lineup `[accountProfileOrNull, null × (count-1)]`.

- [ ] **Step 1: Rewrite play-menu tests.** In `play_menu_screen_test.dart` replace tests that add manual profiles / expect `PlayerSelectScreen` with: `starts with all guests when no account profile` (lineup all null, header shows "Player 1"…), `seats the signed-in account in seat 1` (use `playerStorage.ensureAccountProfile('u1','Levon')`; expect `GameScreen.lineup[0]?.name == 'Levon'`, rest null), `ignores legacy non-account profiles` (write one via `SharedPreferences.setMockInitialValues({'dice_zee.players': <json with linkedToAccount false>})`; lineup all null; no `PlayerSelectScreen`).
- [ ] **Step 2:** Run `flutter test test/widgets/play_menu_screen_test.dart` — expect FAIL.
- [ ] **Step 3:** In `_start()`: load profiles, pick `firstWhereOrNull(linkedToAccount)`, call `_openGame([account, for (i in 1..<_count) null])`. Remove `PlayerSelectScreen` import and branches. Delete the two select-screen files.
- [ ] **Step 4:** Run the test file and `flutter analyze` — expect PASS / clean.
- [ ] **Step 5: Commit** `git add -A lib test && git commit -m "Start offline games directly with account/guest lineup"`

### Task 2: Statistics shows Everyone plus the signed-in account only

**Files:**
- Modify: `lib/widgets/statistics_screen.dart`
- Test: `test/widgets/statistics_screen_test.dart`

**Interfaces:**
- Consumes: `PlayerStorage.loadProfiles()`, `Statistics.from(history, profileId:, mode:)`, `PlayerStatsScreen`.
- Produces: rows `stats_everyone` and `stats_<accountProfileId>` (only the `linkedToAccount` profile, only when `gamesPlayed > 0` in the selected mode).

- [ ] **Step 1: Update tests** (replace `addProfile` uses with `ensureAccountProfile('u1','Levon')`): `shows only Everyone when signed out`, `shows account row when it has games in the mode`, `hides account row when it has no games in the mode`, `legacy manual profiles never appear` (stored non-linked profile with games → no row).
- [ ] **Step 2:** Run `flutter test test/widgets/statistics_screen_test.dart` — expect FAIL.
- [ ] **Step 3:** In `_StatisticsScreenState.build`, filter `profiles` to `linkedToAccount` and skip a row whose `Statistics.from(...).gamesPlayed == 0`. Update the class doc comment.
- [ ] **Step 4:** Run the test file and `flutter analyze` — PASS / clean.
- [ ] **Step 5: Commit** `git commit -am "Statistics: Everyone plus signed-in account only"`

### Task 3: Remove Players screen and local-player sync

**Files:**
- Delete: `lib/widgets/players_screen.dart`, `test/widgets/players_screen_test.dart`
- Modify: `lib/widgets/main_menu.dart` (drop Players button, `_openPlayers`, import), `lib/services/player_storage.dart` (remove `addProfile`, `renameProfile`, `deleteProfile`, `replaceProfiles`; keep `loadProfiles`, `ensureAccountProfile`, `removeAccountProfile`), `lib/services/cloud_store.dart` + `lib/services/firestore_cloud_store.dart` (remove `loadPlayers`/`savePlayers` and the `players` field handling), `lib/services/sync_service.dart` (remove `_pullPlayers`, `pushPlayers`, `_syncedUidKey` if unused, `_sameIds`, `PlayerProfile` import; update class doc)
- Test: `test/player_storage_test.dart`, `test/sync_service_test.dart`, `test/widgets/main_menu_test.dart`, `test/player_profile_test.dart` (unchanged unless it references removed API)

**Interfaces:**
- Consumes: none new.
- Produces: `PlayerStorage` public API = `loadProfiles`, `ensureAccountProfile(String uid, String name)`, `removeAccountProfile()`; `CloudStore` = matches methods only.

- [ ] **Step 1: Update tests.** `player_storage_test.dart`: delete add/rename/delete tests; keep and adapt account-profile tests to not use `addProfile`/`renameProfile` (seed via `ensureAccountProfile`; "existing profile left alone" = call twice with different names). `sync_service_test.dart`: remove player-sync tests and `loadPlayers/savePlayers` fake members. `main_menu_test.dart`: assert no "Players" text; assert buttons Play, Online, Statistics, Account exist (Online added in Task 5 — here just assert Players is absent).
- [ ] **Step 2:** Run `flutter test` — expect FAIL (compile errors/absent behavior).
- [ ] **Step 3:** Delete/trim the code listed above.
- [ ] **Step 4:** `flutter test` and `flutter analyze` — all PASS / clean.
- [ ] **Step 5: Commit** `git add -A && git commit -m "Remove Players screen and local player management"`

### Task 4: Online matches screen gains New game and Friends actions

**Files:**
- Create: `lib/widgets/challenge_mode_dialog.dart`
- Modify: `lib/widgets/friends_screen.dart` (use the shared dialog), `lib/widgets/online_matches_screen.dart`
- Test: `test/widgets/online_matches_screen_test.dart` (create or extend if it exists; use `test/support/in_memory_friend_store.dart` and the existing in-memory online-match store from the online-games tests)

**Interfaces:**
- Produces: `Future<GameMode?> showChallengeModeDialog(BuildContext context, String friendName)` — the `SimpleDialog` currently inline in `FriendsScreen._challenge` (title `Challenge $friendName`, option text `'${m.label} (${m.rounds} rounds)'`).
- Produces: `OnlineMatchesScreen({required AccountUser user, OnlineMatchService? service, FriendService? friendService})`; app bar action `Friends` (icon `Icons.group`, key `friends_action`) pushes `FriendsScreen(user:, service: friendService, onlineService: service)`; `FloatingActionButton.extended` (key `new_game_button`, label "New game") opens the friend picker.
- Friend picker: bottom sheet listing `FriendsOverview.friends` (`friendService.myProfile` + `.load`); tap a friend → `showChallengeModeDialog` → `OnlineMatchService.challenge(me, friend, mode)` → snackbar `Challenge sent to ${friend.name}.`. With no friends: sheet text "Add a friend first" and a button opening FriendsScreen.
- Empty-state text changes to "No online games yet. Tap New game to challenge a friend."

- [ ] **Step 1: Write failing tests:** `new game lists friends and sends a challenge in the chosen mode` (expects a pending match in the in-memory store with that mode, and the snackbar); `new game with no friends shows Add a friend first and opens Friends`; `friends action opens FriendsScreen`; `FriendsScreen challenge still works via the shared dialog` (existing friends test should stay green).
- [ ] **Step 2:** Run `flutter test test/widgets/online_matches_screen_test.dart` — FAIL.
- [ ] **Step 3:** Extract the dialog; implement the actions in `online_matches_screen.dart` (reuse `_guard` for errors). Keep the screen's body (sections) unchanged.
- [ ] **Step 4:** Run `flutter test test/widgets` and `flutter analyze` — PASS / clean.
- [ ] **Step 5: Commit** `git add -A && git commit -m "Online games: new game and friends actions"`

### Task 5: Online hub, main-menu button, trimmed Account page

**Files:**
- Create: `lib/widgets/online_hub_screen.dart`
- Modify: `lib/widgets/main_menu.dart`, `lib/widgets/account_screen.dart` (remove Friends and Online games buttons and now-unused imports/`friendService` only if nothing else uses it — the friend-code tile still needs it)
- Test: `test/widgets/online_hub_screen_test.dart` (create), `test/widgets/main_menu_test.dart`, `test/widgets/account_screen_test.dart`

**Interfaces:**
- Consumes: `AuthService` (`currentUser`, `authStateChanges()`), `OnlineMatchesScreen` from Task 4, `AccountScreen(authService:)`.
- Produces: `OnlineHubScreen({AuthService? authService, OnlineMatchService? matchService, FriendService? friendService})`. Signed out: scaffold titled "Online games", text "Sign in to play online with friends", `FilledButton` (key `hub_sign_in`) pushing `AccountScreen(authService: …)`. Signed in: renders `OnlineMatchesScreen(user:, service: matchService, friendService:)`. Reacts to `authStateChanges()` both ways. `MainMenuScreen` Online button (key `online_button`, icon `Icons.casino`, between Play and Statistics) pushes `OnlineHubScreen(authService: widget.authServiceBuilder?.call())`.

- [ ] **Step 1: Write failing tests:** hub signed out shows prompt and opens Account on tap; hub signed in shows the matches list (fake auth with a user); hub flips to prompt when the auth stream emits null; main menu has `online_button` and tapping it opens the hub; account page (signed in) has no "Friends" or "Online games" button but still shows the friend code and Sign out.
- [ ] **Step 2:** Run those test files — FAIL.
- [ ] **Step 3:** Implement `OnlineHubScreen` (`StreamBuilder<AccountUser?>` with `initialData: auth.currentUser`; do not construct match/friend services until signed in). Add the menu button; remove the two Account buttons.
- [ ] **Step 4:** `flutter test` (whole suite) and `flutter analyze` — PASS / clean.
- [ ] **Step 5: Commit** `git add -A && git commit -m "Add Online hub to the main menu"`

### Task 6: Docs

**Files:** Modify `CLAUDE.md`.

- [ ] **Step 1:** Update CLAUDE.md: project structure (remove players screens/storage mutators, add `OnlineHubScreen`, `challenge_mode_dialog.dart`), menu description (Play/Online/Statistics/Account), "Online games" section (hub entry, New game flow), persistence note (`dice_zee.players` holds only the account profile; players no longer synced). Add spec link under "Design specs".
- [ ] **Step 2:** Run `flutter test && flutter analyze` — all green.
- [ ] **Step 3: Commit** `git commit -am "Document online hub and player removal"`

## Self-review notes
- Spec coverage: menu (T3,T5), hub + New game + Friends + signed-out prompt (T4,T5), Account trim (T5), offline Player N/account seat (T1), statistics (T2), removal + sync (T3), docs (T6). Spec says account stats row only "if games were played"; T2 implements that.
- Signatures used across tasks match: `OnlineMatchesScreen.friendService` (T4) is consumed by `OnlineHubScreen` (T5).
