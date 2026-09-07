# Fix: The last rows of the score table and the statistics list hide under the phone's bottom system bar

> Follow the steps in order. Run every check. If anything in "STOP if"
> happens, stop and report instead of improvising.

- **Link**: https://flutterpro.design/details/md/safe-area-replacement
- **Needs new dependency**: none

## Why

The game screen and the statistics screen each scroll a tall list to the very
bottom of the window. On Android phones with a gesture bar or 3-button
navigation bar, the last row (the score table's **Total** row; the last
"best by category" entry) sits underneath that bar with no gap, so it is hard
to read and hard to tap. The fix adds a spacer at the end of each scroll area
that is exactly as tall as the device's bottom bar (and at least 16px when
there is no bar), so the last row always clears it.

## Where

Two scrollables run to the bottom of the screen with no bottom inset.

```dart
// lib/widgets/game_screen.dart:118-164 — current
    return Scaffold(
      appBar: AppBar(title: const Text('Dice Zee')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                "Player ${_game.currentPlayer + 1}'s turn",
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Round ${_game.round.clamp(1, 15)} / 15'),
                  Text('Rolls left: ${_game.rollsRemaining}'),
                ],
              ),
            ),
            DiceRow(
              dice: _game.dice,
              held: _game.held,
              canHold: canAct,
              rollCount: _rollCount,
              onToggleHold: _toggleHold,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: canRoll ? _roll : null,
              icon: const Icon(Icons.casino),
              label: const Text('Roll'),
            ),
            const SizedBox(height: 16),
            ScoreTable(
              cards: _game.scoreCards,
              currentPlayer: _game.currentPlayer,
              currentDice: _game.dice,
              canCommit: canAct,
              onCommit: _commit,
            ),
          ],
        ),
      ),
    );
```

```dart
// lib/widgets/statistics_screen.dart:51-83 — current
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Games played: ${stats.gamesPlayed}',
            style: theme.textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            'Average score: ${stats.averageScore.toStringAsFixed(1)}',
            style: theme.textTheme.titleMedium,
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Best ever by category', style: theme.textTheme.titleMedium),
        ),
        for (final entry in stats.bestByCategory.entries)
          ListTile(
            key: ValueKey('best_${entry.key.name}'),
            dense: true,
            title: Text(categoryLabel(entry.key)),
            trailing: Text(
              '${entry.value}',
              style: theme.textTheme.bodyLarge,
            ),
          ),
      ],
    );
```

## The fix

Add the article's `BottomPadding` helper as a new file, then use
`BottomPadding.of(context)` as bottom padding on both scrollables.

New file — copy verbatim:

```dart
// lib/widgets/bottom_padding.dart — target (new file)
import 'package:flutter/widgets.dart';

/// Bottom breathing room for a scrollable that reaches the screen edge:
/// as tall as the device's bottom system bar, or [minimum] when there is none.
///
/// Use `SafeArea` never wraps a scrollable — it shrinks the viewport so items
/// get clipped as they pass the bottom. This adds padding instead.
class BottomPadding extends StatelessWidget {
  const BottomPadding({super.key});

  static double of(BuildContext context, {double minimum = 16}) {
    final double viewPadding = MediaQuery.viewPaddingOf(context).bottom;
    return viewPadding > minimum ? viewPadding : minimum;
  }

  @override
  Widget build(BuildContext context) => SizedBox(height: of(context));
}
```

Game screen — add a `padding` to the `SingleChildScrollView`:

```dart
// lib/widgets/game_screen.dart — target
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: BottomPadding.of(context)),
        child: Column(
```

Statistics screen — add a `padding` to the `ListView`:

```dart
// lib/widgets/statistics_screen.dart — target
    return ListView(
      padding: EdgeInsets.only(bottom: BottomPadding.of(context)),
      children: [
```

Match how this codebase writes widgets; imitate the existing small
single-purpose widget files like `lib/widgets/dice_row.dart`.

## Steps

1. Create `lib/widgets/bottom_padding.dart` with the exact contents shown above
   under "New file".
2. In `lib/widgets/game_screen.dart`, add the import
   `import 'bottom_padding.dart';` next to the other `import '...';` lines at
   the top of the file (they are grouped; keep alphabetical order — it goes
   before `import 'dice_row.dart';`).
3. In `lib/widgets/game_screen.dart`, change the `body: SingleChildScrollView(`
   line (currently line 120) to add
   `padding: EdgeInsets.only(bottom: BottomPadding.of(context)),` as the first
   argument, so it reads:
   ```dart
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: BottomPadding.of(context)),
        child: Column(
   ```
4. In `lib/widgets/statistics_screen.dart`, add the import
   `import 'bottom_padding.dart';` — alphabetical order puts it before
   `import 'score_table.dart';`.
5. In `lib/widgets/statistics_screen.dart`, change `return ListView(` (currently
   line 51) to:
   ```dart
    return ListView(
      padding: EdgeInsets.only(bottom: BottomPadding.of(context)),
      children: [
   ```

## Check it

- `dart analyze` exits clean.
- `test -f lib/widgets/bottom_padding.dart` succeeds.
- `grep -c "BottomPadding.of(context)" lib/widgets/game_screen.dart` → `1`.
- `grep -c "BottomPadding.of(context)" lib/widgets/statistics_screen.dart` → `1`.
- `grep -c "import 'bottom_padding.dart';" lib/widgets/game_screen.dart` → `1`.
- `grep -c "import 'bottom_padding.dart';" lib/widgets/statistics_screen.dart` → `1`.
- `flutter test` still passes (the existing widget tests pump these screens; a
  `SizedBox` at the end of the scroll does not change any finder).

## Don't touch

- `lib/widgets/main_menu.dart` — its body is a centered non-scrolling column, so
  the rule does not apply. Its `SafeArea` there is correct and unrelated.
- `lib/widgets/score_table.dart` — the `Table` is not a scrollable; leave it.
- Do not wrap either scrollable in `SafeArea`; that is the wrong fix (it clips
  items instead of padding them).
- No new dependencies. No refactors beyond the two `padding:` additions and the
  one new file.

## STOP if

- The code at either location in "Where" doesn't match the quoted excerpt
  (the codebase moved on since this plan was written).
- Either screen's scrollable already sets a `padding:` argument — merge the
  `bottom:` value into it rather than adding a second `padding:`.
- The fix seems to require touching something in "Don't touch".
- A check fails twice.

## When you're done

Play a game to the end and scroll the score table down: the **Total** row now
sits above the phone's bottom bar with a clear gap instead of tucked under it.
The same is true at the bottom of the Statistics screen. Open
`lib/widgets/game_screen.dart` to see the change.
