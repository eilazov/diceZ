# Dice Zee — Local Player Profiles

**Date:** 2026-09-10
**Status:** Approved
**Builds on:** [2026-09-07-multiplayer-and-menu-design.md](2026-09-07-multiplayer-and-menu-design.md)

## Goal

Let the owner create named players on the device, assign them to seats when
starting a match, and see statistics for one player at a time. Names replace
"Player N" wherever a seat is shown. Keep starting a game friction-free: only
ask who is playing when there is an actual choice to make.

## Non-goals

- No accounts, no sync, no network — everything is local `shared_preferences`.
- No avatars, colours, or per-player settings. A profile is just a name (seat
  colour still comes from `SeatPalette` by seat index).
- No per-guest tracking. Unassigned seats stay "Player N" and their scores only
  roll up into the **Everyone** statistics entry.
- No change to game rules or to `DiceGame` — it stays pure and is still
  constructed with just `playerCount`.
- No new dependencies. No routing package (plain `Navigator`).
- No history migration — old `GameResult` entries must keep parsing as-is.

## Flow

```
MainMenuScreen
  ├─ Players  → PlayersScreen           (add / rename / delete profiles)
  ├─ Start    → load profiles, then:
  │     0 profiles      → GameScreen, lineup all null  ("Player 1..N")
  │     exactly 1       → GameScreen, lineup [profile, null, ...]  (profile = seat 1)
  │     2+ profiles     → PlayerSelectScreen → GameScreen(lineup)
  └─ Statistics → StatisticsScreen (Everyone + one row per profile)
                    → PlayerStatsScreen (scoped detail)
```

The player-count control (2 / 3 / 4) stays on the main menu. The
exactly-1-profile path skips the select screen even for a 3- or 4-player match —
there is no one else to assign.

## Data model

### `lib/models/player_profile.dart` (new, plain Dart)

```dart
class PlayerProfile {
  const PlayerProfile({required this.id, required this.name});
  final String id;
  final String name;
  Map<String, dynamic> toJson();
  factory PlayerProfile.fromJson(Map<String, dynamic> json);
}
```

- `id` is generated at creation as
  `DateTime.now().microsecondsSinceEpoch.toString()`. Stable for the life of the
  profile; never reused.
- `name` is free text, trimmed, non-empty (enforced by the UI, not the model).

### `lib/models/game_result.dart` (extend `PlayerScore`)

Add two nullable fields to `PlayerScore`:

- `final String? profileId;` — attribution key for statistics.
- `final String? name;` — snapshot of the display name at the time the match
  was played, so history stays readable after a rename or delete.

`toJson` writes `profileId` and `name` alongside the category-score keys.
`fromJson` reads both as nullable — a stored entry that has neither (every
entry written before this feature) parses with both `null`. No migration.

A guest seat is persisted as a `PlayerScore` with `profileId == null` and
`name == null`.

### `lib/models/statistics.dart` (extend)

```dart
factory Statistics.from(List<GameResult> history, {String? profileId});
```

- `profileId == null` → **Everyone**: aggregates every `PlayerScore` in every
  game — identical to today's behaviour.
- `profileId` non-null → aggregates only `PlayerScore`s whose `profileId`
  matches.

Fields:

- `gamesPlayed` — number of games in which this scope appears (for a profile,
  the number of games that profile has a slot in).
- `averageScore` — mean final total over the scoped slots; `0.0` when none.
- `bestByCategory` — highest value ever committed to each category within scope;
  `0` when never scored in scope.
- `wins` (new) — count of games where a scoped slot held the **strictly
  highest** total in that game. Ties credit nobody (matches
  `DiceGame.winner`). Only surfaced in the per-profile detail view, never for
  Everyone.

## Storage

### `lib/services/player_storage.dart` (new, sibling to `GameStorage`)

`shared_preferences`, single key `dice_zee.players`, holding a JSON list of
`PlayerProfile`.

- `Future<List<PlayerProfile>> loadProfiles()` — decode the list, silently
  dropping any entry that fails to parse (same tolerance pattern as
  `GameStorage.loadHistory`). Order is insertion order (newest last).
- `Future<void> addProfile(String name)` — append a new profile with a fresh id.
- `Future<void> renameProfile(String id, String name)` — replace the name of the
  matching profile; no-op if the id is absent.
- `Future<void> deleteProfile(String id)` — remove the matching profile.
  Nothing else is touched: past `GameResult`s keep their `profileId` and name
  snapshot, so those matches still display the old name and still count under
  **Everyone**; only the profile's own tappable stats row disappears.

`GameStorage` is unchanged.

## Screens

### `main_menu.dart` (rework)

- Add a **Players** `OutlinedButton.icon` next to **Statistics**.
- `_startGame` becomes async:
  1. `PlayerStorage().loadProfiles()`.
  2. `profiles.isEmpty` → push `GameScreen` with a lineup of `_count` nulls.
  3. `profiles.length == 1` → push `GameScreen` with lineup
     `[profiles.single, ...nulls]` of length `_count`.
  4. otherwise → push `PlayerSelectScreen(playerCount: _count)`.
- Storage is injectable (`PlayerStorage` constructor arg) for tests, mirroring
  the existing `GameStorage` seam.

### `lib/widgets/player_select_screen.dart` (new)

- `playerCount` rows labelled "Seat 1" … "Seat N" (turn order; seat 1 goes
  first).
- Each row is a picker (`DropdownButton` / `DropdownMenu`) whose options are
  **Guest** plus every profile. A profile chosen in another row is shown
  disabled, so no profile can take two seats.
- All rows default to **Guest**.
- A **Start match** `FilledButton` builds `List<PlayerProfile?>` (null for
  Guest rows) and `Navigator.pushReplacement`es to `GameScreen(lineup: …)`.
- Takes an injectable `PlayerStorage`.

### `lib/widgets/players_screen.dart` (new)

- `FutureBuilder` / stateful load of `loadProfiles()`.
- List of profiles: tap a row to **rename** (text-field dialog, pre-filled,
  trimmed, non-empty), trailing delete icon to **delete** (confirm dialog).
- A **＋ Add player** action (app-bar action or bottom button) opens a
  name dialog.
- Empty state mirrors `StatisticsScreen`'s empty state ("No players yet." +
  hint).
- After every mutation, reload the list and `setState`.

### `lib/widgets/statistics_screen.dart` (rework — list view)

- `FutureBuilder` over **both** `loadHistory()` and `loadProfiles()`.
- Renders a list:
  - an **Everyone** row — subtitle "N games".
  - one row per profile — subtitle "N games · W wins".
- Empty state unchanged (no games played yet).
- Tapping a row pushes `PlayerStatsScreen` (Everyone → `profileId: null`).

### `lib/widgets/player_stats_screen.dart` (new)

- Reuses the current `_StatsBody` layout: two stat cards + the
  best-by-category grid.
- App-bar title is the profile name (or "Everyone").
- Scopes its data with `Statistics.from(history, profileId: …)`.
- For a profile, one of the two stat cards shows **Wins**; Everyone keeps the
  current "Games played" + "Average score" pair.

(The existing `_StatsBody`, `_StatCard`, `_BestTile` move to this file; the
`categoryLabel` import stays from `score_table.dart`.)

### `game_screen.dart` (thread names)

- `GameScreen` gains `final List<PlayerProfile?> lineup;` and derives
  `playerCount` from `lineup.length`. The old `playerCount` constructor arg is
  removed; callers pass a lineup (all-null for the no-profile paths).
- A local resolver `String seatName(int seat) =>
  lineup[seat]?.name ?? SeatPalette.label(seat)` is passed down to
  `_TurnHeader`, `_HandoffCover`, `ScoreTable` (column headers), and
  `ResultsScreen` (`_StandingRow`). Those widgets take a `String name` (or a
  `String Function(int)`); `SeatPalette` keeps the colour API and the
  `"Player N"` fallback string unchanged.
- `_buildResult()` sets each `PlayerScore`'s `profileId: lineup[p]?.id` and
  `name: lineup[p]?.name`.
- **Rematch** carries the same `lineup` through to the new `GameScreen`.

### `results_screen.dart` / `score_table.dart` (accept names)

- `ResultsScreen` gains a `List<String> names` (already resolved) or a
  `String Function(int seat)` and uses it wherever `SeatPalette.label(seat)`
  is currently called for a row/heading. Colours still come from
  `SeatPalette.color`.
- `ScoreTable` column headers take the resolved name; short/`PN` forms stay for
  the tightest layouts if needed.

## Testing (test-first)

Model / service:

- `test/player_profile_test.dart` — `toJson` / `fromJson` round-trip.
- `test/player_storage_test.dart` — add / rename / delete / load ordering /
  unparseable-entry skip, against the `shared_preferences` mock.
- `test/game_result_test.dart` — `profileId` + `name` round-trip; **a legacy
  entry with neither key still parses** (both `null`).
- `test/statistics_test.dart` — `profileId` filtering; `wins` including the
  tie-credits-nobody case; empty history; Everyone == pre-feature numbers.

Widget:

- `test/widgets/player_select_screen_test.dart` — seat rows render, a picked
  profile is disabled in other rows, Start passes the expected lineup.
- `test/widgets/players_screen_test.dart` — add / rename / delete each round-trip
  through an injected `PlayerStorage`; empty state.
- `test/widgets/statistics_screen_test.dart` — Everyone row + one row per
  profile with correct game/win counts; tap navigates to the detail.
- `test/widgets/player_stats_screen_test.dart` — scoped figures; Wins card for a
  profile, not for Everyone.
- `test/widgets/main_menu_test.dart` — 0 / 1 / 2-profile branching from Start;
  Players button navigates.
- `test/widgets/game_screen_test.dart` — a profile name appears in the turn
  header, the handoff cover, and the results standings; a guest seat shows
  "Player N".

`flutter analyze` stays clean; no new dependency in `pubspec.yaml`.

## Files touched

New:
`lib/models/player_profile.dart`,
`lib/services/player_storage.dart`,
`lib/widgets/player_select_screen.dart`,
`lib/widgets/players_screen.dart`,
`lib/widgets/player_stats_screen.dart`
(+ their test files).

Changed:
`lib/models/game_result.dart`,
`lib/models/statistics.dart`,
`lib/widgets/main_menu.dart`,
`lib/widgets/statistics_screen.dart`,
`lib/widgets/game_screen.dart`,
`lib/widgets/results_screen.dart`,
`lib/widgets/score_table.dart`
(+ their test files).

Unchanged:
`lib/models/dice_game.dart`,
`lib/models/score_card.dart`,
`lib/services/game_storage.dart`,
`lib/seat_palette.dart` (public API).
