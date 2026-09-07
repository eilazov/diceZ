# Dice Zee

Personal-use Yatzy-style dice game. Flutter, targeting iOS + Android by sideload
only — no App Store / Play Store release.

Design specs (newest last):
- [docs/superpowers/specs/2026-09-07-dice-zee-design.md](docs/superpowers/specs/2026-09-07-dice-zee-design.md) — core single-player game
- [docs/superpowers/specs/2026-09-07-multiplayer-and-menu-design.md](docs/superpowers/specs/2026-09-07-multiplayer-and-menu-design.md) — 2–4 players, menu, statistics

## Gameplay

2–4 players, hot-seat on one device. A match is 15 rounds. On a player's turn they
roll up to 3 times (holding any dice between rolls), then commit the dice to one
of their 15 still-open categories; the device then passes to the next player. The
match ends when every player has filled all 15 categories. Highest total wins
(a shared top total is a tie). Each finished match is saved to local history.

15 categories: ones–sixes, one pair, two pairs, three of a kind, four of a kind,
full house (25), small straight (30), large straight (40), Dice Zee / yahtzee
(100), chance. No upper-section bonus, no bonus-yahtzee, no joker rules. Full
scoring table is in the core design spec.

There is no single-player or bot mode.

## Project structure

```
lib/
  models/            (plain Dart, no package:flutter import, unit-tested directly)
    score_card.dart    ScoreCategory enum + ScoreCard: pure static score(), plus
                       committed-score state (commit / isFilled / total / isComplete).
    dice_game.dart      DiceGame: a 2–4 player match. currentPlayer, round, per-turn
                       dice/held/rolls, one ScoreCard per seat, standings, winner.
                       Injectable RNG.
    game_result.dart    GameResult (playedAt, playerCount, List<PlayerScore>) +
                       PlayerScore (per-category map, total) + JSON.
    statistics.dart     Statistics.from(history): gamesPlayed, averageScore,
                       bestByCategory.
  services/
    game_storage.dart   shared_preferences wrapper: saveResult / loadHistory
                       (skips unparseable legacy entries).
  widgets/
    main_menu.dart       MainMenuScreen: 2/3/4-player buttons + Statistics.
    game_screen.dart     StatefulWidget; owns DiceGame; turn banner, standings
                       strip, end-of-match summary + save. setState on every action.
    dice_row.dart        the 5 dice; tap to hold; roll animation.
    score_card_view.dart 15-row score sheet; preview open rows; tap to commit.
                       Owns categoryLabel().
    statistics_screen.dart  FutureBuilder over history -> Statistics table.
  main.dart              DiceZeeApp: light/dark seeded themes -> MainMenuScreen.
test/
  score_card_test.dart      every scoring function + ScoreCard instance behavior.
  dice_game_test.dart       construction, roll / hold, turn + round advancement,
                            standings, winner.
  game_result_test.dart     PlayerScore / GameResult JSON round-trips.
  statistics_test.dart      aggregates, including the empty-history case.
  game_storage_test.dart    save / load / ordering / legacy-skip (prefs mock).
  widget_test.dart          app boots to the menu.
  widgets/                   one test file per widget.
```

## State management & navigation

Plain `StatefulWidget` + `setState`. `GameScreen` holds one `DiceGame` and rebuilds
on roll, hold-toggle, and commit; `StatisticsScreen` holds a `Future`. `DiceRow`,
`ScoreCardView`, `MainMenuScreen` are stateless, taking data + callbacks. No
Provider / Riverpod / Bloc / InheritedWidget.

Navigation is plain `Navigator.push(MaterialPageRoute(...))` from the menu — no
routing package.

## Persistence

`shared_preferences` only — a single JSON key (`dice_zee.history`) holding a list
of `GameResult`. `loadHistory` silently drops entries it can't parse, so a schema
change doesn't need a migration for this personal app. Statistics are derived from
that list, not stored separately.

## Dependencies

`shared_preferences` is the only non-SDK dependency. **Do not add another package
without asking the author first.**

## Commands

```bash
flutter pub get          # after changing pubspec.yaml
flutter test             # run all tests
flutter analyze          # static analysis (lints from flutter_lints)
flutter run              # run on the connected device / emulator
flutter build apk        # Android sideload build (needs Android SDK)
flutter build ios        # iOS build (needs macOS + Xcode)
```

Run a single test file: `flutter test test/score_card_test.dart`

## Coding conventions

- **Small, single-responsibility files.** One model / widget / service per file.
  If a file starts doing two things, split it.
- **Pure logic separated from widgets.** Everything in `models/` and `services/`
  is plain Dart with no `package:flutter` import and is unit-tested directly.
  Widgets hold no game rules — they render state and forward callbacks.
- **Test-first.** Write the failing test before the implementation, for both new
  behavior and bug fixes. Model logic must have direct unit tests.
- **Deterministic tests.** Inject `Random` (or other nondeterminism) through
  constructors so tests can seed it.
- Keep `flutter analyze` clean — no new warnings.
- Prefer `const` constructors and immutable data where practical.
