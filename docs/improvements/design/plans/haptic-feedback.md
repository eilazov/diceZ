# Fix: Rolling dice, holding a die and scoring happen in total silence

> Follow the steps in order. Run every check. If anything in "STOP if"
> happens, stop and report instead of improvising.

- **Link**: https://flutterpro.design/details/md/haptic-feedback
- **Needs new dependency**: none — see note below

## Why

A dice game that produces no physical feedback feels flat in the hand. Rolling
five dice, tapping a die to hold it, committing a score and winning the match
are all moments that should register as a small vibration. Adding light,
selection and impact haptics at those four points makes the game feel
responsive without the player consciously noticing.

**Dependency note:** the article recommends the `haptic_feedback` pub package
for richer haptic types (success / warning / error). This project's `CLAUDE.md`
forbids adding any package without the author's approval, and Flutter's built-in
`HapticFeedback` (from `package:flutter/services.dart`) covers everything this
game needs. This plan uses the built-in API only, wrapped in a small helper as
the article suggests. If the author later approves `haptic_feedback`, the helper
is the one place to swap the implementation.

## Where

No haptic calls exist anywhere in `lib/`. The four moments to cover, all in
`lib/widgets/game_screen.dart`:

```dart
// lib/widgets/game_screen.dart:40-59 — current
  void _roll() {
    setState(() {
      _game.roll();
      _rollCount++;
    });
  }

  void _toggleHold(int index) => setState(() => _game.toggleHold(index));

  Future<void> _commit(ScoreCategory category) async {
    setState(() {
      _game.commitScore(category);
      _rollCount++;
    });
    if (_game.isOver && !_summaryShown) {
      _summaryShown = true;
      await widget.storage.saveResult(_buildResult());
      if (mounted) await _showSummary();
    }
  }
```

## The fix

Add a helper file, then call it from the four handlers.

New file — `lib/haptics.dart` (kept at the `lib/` root, not under `services/`,
because `CLAUDE.md` requires `lib/services/` to stay free of `package:flutter`
imports and this helper imports `flutter/services.dart`):

```dart
// lib/haptics.dart — target (new file)
import 'package:flutter/services.dart';

/// Small haptic vocabulary for the game's key moments. Each method maps to a
/// built-in [HapticFeedback] call; all are no-ops on devices or platforms
/// (web, most desktops) that don't support vibration.
abstract final class AppHaptics {
  /// The dice tumble.
  static void roll() => HapticFeedback.mediumImpact();

  /// A die is held or released.
  static void hold() => HapticFeedback.selectionClick();

  /// A category is committed.
  static void commit() => HapticFeedback.lightImpact();

  /// The match is over.
  static void gameOver() => HapticFeedback.heavyImpact();
}
```

Then wire the four calls into `lib/widgets/game_screen.dart`:

```dart
// lib/widgets/game_screen.dart — target
  void _roll() {
    AppHaptics.roll();
    setState(() {
      _game.roll();
      _rollCount++;
    });
  }

  void _toggleHold(int index) {
    AppHaptics.hold();
    setState(() => _game.toggleHold(index));
  }

  Future<void> _commit(ScoreCategory category) async {
    AppHaptics.commit();
    setState(() {
      _game.commitScore(category);
      _rollCount++;
    });
    if (_game.isOver && !_summaryShown) {
      _summaryShown = true;
      AppHaptics.gameOver();
      await widget.storage.saveResult(_buildResult());
      if (mounted) await _showSummary();
    }
  }
```

Match this codebase's style: `abstract final class` with `static` methods is how
a stateless namespace is written here (see `ScoreCard.score` being a pure static
in `lib/models/score_card.dart`).

## Steps

1. Create `lib/haptics.dart` with the exact contents shown above.
2. In `lib/widgets/game_screen.dart`, add `import '../haptics.dart';` with the
   other imports at the top. Alphabetical order within the relative-import group
   puts it after `import '../services/game_storage.dart';` and before
   `import 'dice_row.dart';` — actually `../haptics.dart` sorts before
   `../models/...`; place it right after `import 'package:flutter/material.dart';`
   and its blank line, as the first relative import.
3. In `_roll()`, add `AppHaptics.roll();` as the first line of the method body
   (before `setState`).
4. Replace the one-line `_toggleHold` with the three-line version shown above
   (`AppHaptics.hold();` then `setState(...)`).
5. In `_commit()`, add `AppHaptics.commit();` as the first line of the method
   body (before `setState`).
6. In `_commit()`, inside the `if (_game.isOver && !_summaryShown)` block, add
   `AppHaptics.gameOver();` immediately after `_summaryShown = true;`.

## Check it

- `dart analyze` exits clean.
- `test -f lib/haptics.dart` succeeds.
- `grep -c "AppHaptics\." lib/widgets/game_screen.dart` → `4`.
- `grep -c "import '../haptics.dart';" lib/widgets/game_screen.dart` → `1`.
- `flutter test` still passes. The existing `game_screen_test.dart` drives roll
  and commit under `TestWidgetsFlutterBinding`; `HapticFeedback` calls are
  captured by the test binding and do nothing, so no test changes are needed.

## Don't touch

- `lib/widgets/dice_row.dart` — the die's `onTap` calls back into
  `_toggleHold`, which is where the haptic is added. Do not add a second haptic
  in `dice_row.dart`.
- `lib/widgets/main_menu.dart` — menu button taps are out of scope for this fix.
- Do not add the `haptic_feedback` package or any other dependency.
- Do not add haptics to `_showSummary` beyond the single `gameOver()` call
  placed in `_commit`.

## STOP if

- The `_roll` / `_toggleHold` / `_commit` code doesn't match the quoted excerpt.
- `lib/haptics.dart` already exists.
- A check fails twice.

## When you're done

Run the app on a physical phone (haptics are silent on web and simulators),
start a game and roll: the phone gives a firm tap on every roll, a light tick
when you hold a die, a soft tap when you commit a score, and a strong buzz when
the match ends. The new logic is `lib/haptics.dart`, called from
`lib/widgets/game_screen.dart`.
