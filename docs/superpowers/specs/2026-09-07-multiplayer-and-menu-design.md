# Dice Zee — Multiplayer, Main Menu, Statistics

**Date:** 2026-09-07
**Status:** Approved
**Builds on:** [2026-09-07-dice-zee-design.md](2026-09-07-dice-zee-design.md)

## Goal

Turn the single-player game into a 2–4 player hot-seat game reached from a main
menu, plus an aggregate statistics screen.

## Non-goals

- No 1-player mode and no bot/AI opponent (dropped from an earlier draft).
- No network / online play. Hot-seat pass-and-play on one device.
- No player name entry — seats are "Player 1".."Player 4".
- No mid-game view of other players' full score cards (possible follow-up).
- No routing package — plain `Navigator` + `MaterialPageRoute`.
- Stats are aggregates only: no per-seat win tallies, no vs-bot record,
  no recent-games list.

## Flow

```
MainMenuScreen (app home)
  ├─ New game → choose 2 / 3 / 4 players → GameScreen(playerCount)
  └─ Statistics → StatisticsScreen
```

`GameScreen` returns to the menu when the player leaves or finishes a game.

## Turn structure

Each player's turn: roll up to 3 times, holding any dice between rolls, then
commit the dice to one still-open category on their own card. The device then
passes to the next player. After all `playerCount` players have taken a turn the
round counter advances. The game runs 15 rounds; it is over once every player has
filled all 15 categories. Highest total wins (ties: lowest seat number, only for
display ordering — a tie is still reported as a tie).

## Models

### `dice_game.dart` — `DiceGame` becomes a match

```dart
class DiceGame {
  DiceGame({required int playerCount, Random? random});  // asserts 2 <= playerCount <= 4

  final int playerCount;
  int get currentPlayer;        // 0-based
  int get round;                // 1..15 while playing, 16 once over
  int get rollsRemaining;       // 3 -> 0 within the current turn
  List<int> get dice;           // current turn, unmodifiable
  List<bool> get held;          // current turn, unmodifiable
  bool get hasRolledThisRound;  // "this turn"

  ScoreCard scoreCardFor(int player);
  int totalFor(int player);
  List<int> get standings;      // totals indexed by seat
  bool get isOver;
  int? get winner;              // seat with the strict-highest total, else null (tie / not over)

  void roll();                  // unchanged: guarded by rollsRemaining > 0
  void toggleHold(int index);   // unchanged: only after the first roll of the turn
  void commitScore(ScoreCategory category);  // commit to current player's card, then
                                             // currentPlayer = (currentPlayer + 1) % playerCount;
                                             // if it wrapped to 0, round++;
                                             // reset dice/held/rolls/hasRolled for the next turn
}
```

The single-player no-arg constructor is removed. All `DiceGame` tests move to the
`playerCount` constructor.

### `game_result.dart` — richer result

```dart
class PlayerScore {
  final Map<ScoreCategory, int> categoryScores;  // all 15 categories
  int get total;
  Map<String, dynamic> toJson();                 // keys are ScoreCategory.name
  factory PlayerScore.fromJson(Map<String, dynamic>);
}

class GameResult {
  final DateTime playedAt;
  final int playerCount;
  final List<PlayerScore> players;   // length == playerCount, seat order
  int get winningScore;              // max player total
  Map<String, dynamic> toJson();
  factory GameResult.fromJson(Map<String, dynamic>);
}
```

Stored history is a JSON list of `GameResult` under the existing key
`dice_zee.history`. Any pre-existing entries in the old
`{playedAt, totalScore}` shape are discarded on load (there is no real data yet);
`GameStorage.loadHistory` skips entries it cannot parse.

### `statistics.dart` — pure aggregates

```dart
class Statistics {
  Statistics.from(List<GameResult> history);

  final int gamesPlayed;                       // history.length
  final double averageScore;                   // mean of every PlayerScore.total across
                                               // all games; 0.0 when there are none
  final Map<ScoreCategory, int> bestByCategory; // max committed value seen per category;
                                               // 0 when a category was never scored
}
```

## Services

`game_storage.dart` — unchanged surface (`saveResult`, `loadHistory`), now
carrying the richer `GameResult`. `loadHistory` filters out unparseable entries
instead of throwing.

## Widgets

### `main_menu.dart` — `MainMenuScreen`

Title, a "New game" button that opens a 2/3/4-player chooser (segmented buttons in
a small dialog, or inline), and a "Statistics" button. Selecting a player count
pushes `GameScreen(playerCount: n)`. "Statistics" pushes `StatisticsScreen`.

### `game_screen.dart` — `GameScreen({required int playerCount, GameStorage storage, Random? random})`

- App bar: title, no history icon (stats live on the menu now).
- Turn banner: "Player N's turn".
- Standings strip: one chip per player showing seat + running total, current
  player highlighted.
- `DiceRow` and the Roll button as today, acting on the current turn.
- `ScoreCardView` bound to `game.scoreCardFor(game.currentPlayer)`.
- On `isOver`: build a `GameResult` from every player's card, `saveResult`, then a
  summary dialog — final standings, the winning seat (or "Tie"), and a
  "Back to menu" action that pops to the menu.

### `statistics_screen.dart` — `StatisticsScreen({GameStorage storage})`

Loads history, builds `Statistics.from(...)`, shows: games played, average score
(one decimal), and a 15-row "best ever" table by category. Empty state when no
games have been played.

## `main.dart`

`home: const MainMenuScreen()`. Themes unchanged.

## Task order

1. Multi-player `DiceGame` + `dice_game_test.dart`.
2. `GameResult` + `PlayerScore` + `game_result_test.dart`.
3. `Statistics` + `statistics_test.dart`.
4. `GameStorage` richer result + `game_storage_test.dart`.
5. `GameScreen` multi-player + `game_screen_test.dart`.
6. `MainMenuScreen` + `main_menu_test.dart`.
7. `StatisticsScreen` + `statistics_screen_test.dart`.
8. `main.dart` navigation.
9. Update `CLAUDE.md`.

Each task: red/green TDD, `flutter analyze` clean, its own commit.

## Risks

- Rewriting `DiceGame` breaks its existing tests and `GameScreen`; both are
  updated in the same tasks that change the model.
- `GameResult` shape change invalidates any stored history — acceptable, no real
  data exists.
