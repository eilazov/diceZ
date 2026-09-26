# Dice Zee — Design

**Date:** 2026-09-07
**Status:** Approved
**Type:** Personal-use Yahtzee/Yatzy-style dice game, Flutter, iOS + Android (sideload only, no App Store)

## Goal

A single-player dice game for the author's own devices. One player fills a 15-category
score sheet over 15 rounds; each round gives up to 3 rolls of 5 dice with hold/unhold
between rolls. Game history and high scores persist locally.

## Non-goals

- No App Store / Play Store submission, no signing pipeline beyond local sideload.
- No multiplayer, no accounts, no network.
- No upper-section bonus, no bonus-Yahtzee, no joker rules.
- No external state-management package (Provider/Riverpod/Bloc) for now.
- No separate history screen — history shows in a dialog.

## Package & repository

- Dart package name: `dice_zee` (`lowercase_with_underscores` is required).
- Git repository, `main` branch.
- Dependencies: `shared_preferences` only. `flutter_lints` + `flutter_test` for dev.
  Any further dependency requires the author's approval first.

## Project structure

```
lib/
  models/
    score_card.dart      ScoreCategory enum + ScoreCard (pure scoring + committed state)
    dice_game.dart        DiceGame: round, rolls, dice, held; owns a ScoreCard
    game_result.dart      GameResult value object: playedAt + totalScore
  services/
    game_storage.dart     shared_preferences wrapper: saveResult / loadHistory
  widgets/
    dice_row.dart          the 5 dice; tap to hold/unhold; roll animation
    score_card_view.dart   15-row score sheet; live preview of open rows; tap to commit
    game_screen.dart        StatefulWidget; owns DiceGame; setState on roll/hold/commit
  main.dart                 MaterialApp -> GameScreen
test/
  score_card_test.dart      all 15 scoring functions
  dice_game_test.dart       roll / hold / round-advance / game-over logic
CLAUDE.md
docs/superpowers/specs/2026-09-07-dice-zee-design.md   (this file)
```

`game_result.dart`, `game_storage.dart`, and `dice_game_test.dart` are additions beyond
the original file list: persistence needs a home, and `DiceGame` is pure Dart so testing
it is cheap and consistent with the "pure logic separated from widgets" convention.

## State management

Plain `StatefulWidget` + `setState`. `GameScreen` is the single stateful widget; it holds
one `DiceGame` instance and rebuilds on roll, hold-toggle, and score commit. `DiceRow` and
`ScoreCardView` are stateless and receive data + callbacks. No `InheritedWidget`, no
external package. Revisit only if the widget tree grows enough to make prop-drilling
painful.

## Models

### `score_card.dart`

```dart
enum ScoreCategory {
  ones, twos, threes, fours, fives, sixes,
  onePair, twoPairs,
  threeOfAKind, fourOfAKind,
  fullHouse, smallStraight, largeStraight,
  yahtzee, chance,
}
```

Pure static dispatcher, no `flutter` import:

```dart
int ScoreCard.score(ScoreCategory category, List<int> dice)
```

`dice` is always 5 ints in 1..6. Rules:

| Category        | Score |
|-----------------|-------|
| ones..sixes     | `count(face) * face` |
| onePair         | `2 * highest face that appears >= 2 times`; 0 if no pair |
| twoPairs        | sum of the four dice forming two **distinct** paired faces; 0 otherwise. A triple supplies one pair (`[5,5,5,2,2]` -> 14). Four-of-a-kind alone (`[4,4,4,4,1]`) -> 0 |
| threeOfAKind    | sum of all 5 dice if some face appears >= 3, else 0 |
| fourOfAKind     | sum of all 5 dice if some face appears >= 4, else 0 |
| fullHouse       | 30 if the dice are exactly 3-of-one-face + 2-of-a-different-face, else 0. Five-of-a-kind does **not** count |
| smallStraight   | 40 if any of {1,2,3,4} / {2,3,4,5} / {3,4,5,6} is a subset of the dice, else 0 |
| largeStraight   | 50 if the dice set equals {1,2,3,4,5} or {2,3,4,5,6}, else 0 |
| yahtzee         | 100 if all five dice are equal, else 0 |
| chance          | sum of all 5 dice |

`ScoreCard` instance state:

- `Map<ScoreCategory, int> _committed`
- `void commit(ScoreCategory c, List<int> dice)` — asserts `!isFilled(c)`; stores `score(c, dice)`
- `bool isFilled(ScoreCategory c)`
- `int? scoreOf(ScoreCategory c)`
- `int get total` — sum of committed values
- `bool get isComplete` — `_committed.length == 15`

### `dice_game.dart`

```dart
class DiceGame {
  DiceGame({Random? random});   // injectable RNG for deterministic tests
  int round;                    // 1..15
  int rollsRemaining;           // 3 -> 0 within a round
  List<int> dice;               // 5 ints
  List<bool> held;              // 5 bools
  bool hasRolledThisRound;
  final ScoreCard scoreCard;

  void roll();                  // requires rollsRemaining > 0; re-randomizes non-held dice; rollsRemaining--
  void toggleHold(int index);   // only after the first roll of the round
  void commitScore(ScoreCategory c);  // scoreCard.commit(c, dice); then round++, rollsRemaining = 3,
                                      // held = all false, hasRolledThisRound = false
  bool get isOver;              // scoreCard.isComplete
}
```

### `game_result.dart`

```dart
class GameResult {
  final DateTime playedAt;
  final int totalScore;
  Map<String, dynamic> toJson();
  factory GameResult.fromJson(Map<String, dynamic> json);
}
```

## Services

### `game_storage.dart`

Thin wrapper over `shared_preferences`. One key, `dice_zee.history`, holding a JSON list
of `GameResult`.

- `Future<void> saveResult(GameResult result)` — append and persist
- `Future<List<GameResult>> loadHistory()` — newest first
- High scores are derived from history (sorted by `totalScore` desc), not stored separately.

## Widgets & flow

### `dice_row.dart`

Stateless `DiceRow({ List<int> dice, List<bool> held, void Function(int) onToggleHold })`.
Private `_Die` widget draws pips for 1..6; held dice are visually raised/highlighted.
Roll animation: `TweenAnimationBuilder` doing a scale + slight rotation, keyed to a roll
counter passed in from the parent so it retriggers each roll. Deliberately simple.

### `score_card_view.dart`

Stateless `ScoreCardView({ ScoreCard card, List<int> currentDice, bool canCommit,
void Function(ScoreCategory) onCommit })`. 15 rows grouped upper/lower with a divider.
Open row: greyed preview of `ScoreCard.score(category, currentDice)` when `canCommit`,
tap fires `onCommit`. Filled row: locked number, not tappable. Footer: running total.

### `game_screen.dart`

`StatefulWidget` owning a `DiceGame`.

- App bar: title + history icon (opens a dialog listing past `GameResult`s, newest first,
  with the best score marked).
- Status line: `Round N / 15`, `Rolls left: M`.
- `DiceRow`, then `ScoreCardView`.
- Roll button: disabled when `rollsRemaining == 0` or `isOver`.
- `canCommit` for the score card is `hasRolledThisRound && !isOver`.
- On `isOver`: build a `GameResult`, `await GameStorage().saveResult(...)`, then show a
  summary dialog (final score + top scores) with a "New game" action that replaces the
  `DiceGame` with a fresh one.

### `main.dart`

`runApp(const DiceZeeApp())` -> `MaterialApp` with a light + dark `ThemeData`,
`home: const GameScreen()`.

## Testing

- `test/score_card_test.dart`: every one of the 15 scoring functions — a scoring case
  and a zero/no-match case each, plus edge cases: `twoPairs` with a triple, `fullHouse`
  rejecting five-of-a-kind, both straight windows, `onePair` picking the higher pair.
  Must pass before any widget code is written.
- `test/dice_game_test.dart`: `roll()` respects `held` and the 3-roll cap; `toggleHold`
  gated on `hasRolledThisRound`; `commitScore` advances the round and resets rolls/held;
  `isOver` after 15 commits. Uses a seeded `Random`.
- Run with `flutter test`.

## Build order

1. Scaffold: `flutter create`, `pubspec.yaml`, `CLAUDE.md`, `.gitignore`, first commit.
2. `score_card.dart` + `dice_game.dart` + both test files; `flutter test` green.
3. Widgets + `game_storage.dart` + wire-up in `game_screen.dart` / `main.dart`.
4. `flutter test` green again; author runs `flutter run` on a device.

## Open risks

- Flutter SDK not yet installed on the dev machine; author is installing it. Nothing is
  scaffolded until `flutter` and `dart` are on `PATH`.
- `shared_preferences` on a sideloaded iOS build without a provisioning profile: fine for
  personal sideload, noted in case behavior differs from a store build.
