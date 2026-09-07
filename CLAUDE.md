# Dice Zee

Personal-use Yatzy-style dice game. Flutter, targeting iOS + Android by sideload
only — no App Store / Play Store release.

Design spec: [docs/superpowers/specs/2026-09-07-dice-zee-design.md](docs/superpowers/specs/2026-09-07-dice-zee-design.md)

## Gameplay

One player, 15 rounds. Each round: up to 3 rolls of 5 dice, holding any dice
between rolls, then commit the result to one of the 15 score categories. Game
ends when all categories are filled; the total is saved to local history.

15 categories: ones–sixes, one pair, two pairs, three of a kind, four of a kind,
full house (25), small straight (30), large straight (40), yahtzee (100), chance.
No upper-section bonus, no bonus-yahtzee, no joker rules. Full scoring table is in
the design spec.

## Project structure

```
lib/
  models/
    score_card.dart    ScoreCategory enum + ScoreCard: pure static score(), plus
                       committed-score state (commit / isFilled / total / isComplete).
                       No Flutter imports.
    dice_game.dart      DiceGame: round, rollsRemaining, dice, held, hasRolledThisRound;
                       owns a ScoreCard. RNG injected via constructor. No Flutter imports.
    game_result.dart    GameResult value object (playedAt, totalScore) + JSON.
  services/
    game_storage.dart   shared_preferences wrapper: saveResult / loadHistory.
  widgets/
    dice_row.dart        the 5 dice; tap to hold; roll animation.
    score_card_view.dart 15-row score sheet; preview open rows; tap to commit.
                       Owns categoryLabel().
    game_screen.dart     StatefulWidget; owns DiceGame; setState on every action.
  main.dart              DiceZeeApp: light/dark seeded themes -> GameScreen.
test/
  score_card_test.dart      every scoring function + ScoreCard instance behavior.
  dice_game_test.dart       roll / hold / round-advance / game-over logic.
  game_result_test.dart     JSON round-trip.
  game_storage_test.dart    save / load / ordering (SharedPreferences mock).
  widget_test.dart          app boot smoke test.
  widgets/                   one test file per widget.
```

## State management

Plain `StatefulWidget` + `setState`. `GameScreen` is the only stateful widget: it
holds one `DiceGame` and rebuilds on roll, hold-toggle, and commit. Child widgets
(`DiceRow`, `ScoreCardView`) are stateless and take data + callbacks. No Provider /
Riverpod / Bloc / InheritedWidget. Revisit only if prop-drilling becomes painful.

## Persistence

`shared_preferences` only — a single JSON key holding the list of `GameResult`s.
High scores are derived from that list, not stored separately.

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
