# Fix: Score numbers shift sideways and don't line up as they change

> Follow the steps in order. Run every check. If anything in "STOP if"
> happens, stop and report instead of improvising.

- **Link**: https://flutterpro.design/details/md/tabular-figures
- **Needs new dependency**: none

## Why

In the shared score table, each player's column is a stack of numbers that
should line up, and the preview cell and the Total row change on every roll and
every commit. In the default font a `1` is narrower than an `8`, so as those
numbers change they jump left and right and the columns don't align. Turning on
tabular figures makes every digit the same width, so the numbers stay still and
the columns read cleanly. The same applies to the "best ever by category" values
on the Statistics screen, which form a vertical column.

`FontFeature` is already available through the existing
`import 'package:flutter/material.dart';` — no new import is needed.

## Where

```dart
// lib/widgets/score_table.dart:114-119 — current (filled score cell)
    if (card.isFilled(category)) {
      return _Cell(
        key: ValueKey('cell_${player}_${category.name}'),
        highlight: isCurrent,
        child: Text('${card.scoreOf(category)}', style: theme.textTheme.bodyMedium),
      );
    }
```

```dart
// lib/widgets/score_table.dart:122-132 — current (preview / commit cell)
    if (isCurrent && canCommit) {
      return _Cell(
        key: ValueKey('commit_${category.name}'),
        highlight: true,
        onTap: () => onCommit(category),
        child: Text(
          '${ScoreCard.score(category, currentDice)}',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.disabledColor),
        ),
      );
    }
```

```dart
// lib/widgets/score_table.dart:153-161 — current (totals row cells)
        for (var p = 0; p < cards.length; p++)
          _Cell(
            key: ValueKey('total_$p'),
            highlight: p == currentPlayer,
            child: Text(
              '${cards[p].total}',
              style: theme.textTheme.titleSmall,
            ),
          ),
```

```dart
// lib/widgets/statistics_screen.dart:72-81 — current (best-by-category value)
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
```

## The fix

Add `fontFeatures: const [FontFeature.tabularFigures()]` to the `TextStyle` of
each of those four number `Text` widgets. Where the style comes from the theme,
use `.copyWith`.

```dart
// lib/widgets/score_table.dart — target (filled score cell)
        child: Text(
          '${card.scoreOf(category)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
```

```dart
// lib/widgets/score_table.dart — target (preview / commit cell)
        child: Text(
          '${ScoreCard.score(category, currentDice)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.disabledColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
```

```dart
// lib/widgets/score_table.dart — target (totals row cells)
            child: Text(
              '${cards[p].total}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
```

```dart
// lib/widgets/statistics_screen.dart — target (best-by-category value)
            trailing: Text(
              '${entry.value}',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
```

## Steps

1. In `lib/widgets/score_table.dart`, in the `if (card.isFilled(category))`
   branch of `_scoreCell` (currently line ~118), replace the one-line
   `child: Text('${card.scoreOf(category)}', style: theme.textTheme.bodyMedium),`
   with the multi-line target shown above.
2. In `lib/widgets/score_table.dart`, in the `if (isCurrent && canCommit)`
   branch (currently lines ~127-130), replace the `child: Text(...)` with the
   target that keeps `color: theme.disabledColor` and adds `fontFeatures`.
3. In `lib/widgets/score_table.dart`, in `_totalsRow` (currently lines
   ~157-160), replace the totals `child: Text(...)` with the target that adds
   `fontFeatures` via `.copyWith` on `titleSmall`.
4. In `lib/widgets/statistics_screen.dart`, in the `for (final entry in
   stats.bestByCategory.entries)` loop (currently lines ~77-80), replace the
   `trailing: Text(...)` with the target that adds `fontFeatures` via
   `.copyWith` on `bodyLarge`.

## Check it

- `dart analyze` exits clean.
- `grep -c "FontFeature.tabularFigures()" lib/widgets/score_table.dart` → `3`.
- `grep -c "FontFeature.tabularFigures()" lib/widgets/statistics_screen.dart` → `1`.
- `flutter test` still passes. The existing `score_table_test.dart` and
  `statistics_screen_test.dart` find these numbers with `find.text('25')`,
  `find.text('100')` etc.; changing the `TextStyle` does not change the text.

## Don't touch

- The category-label `Text` in `score_table.dart` (`categoryShortLabel`) and the
  `P1`/`P2` header `Text` — those are words, not changing numbers; leave them.
- `Text('Round ... / 15')` and `Text('Rolls left: ...')` in `game_screen.dart` —
  single digits sitting in a sentence; the rule says leave those.
- `'Games played: ...'` and `'Average score: ...'` in `statistics_screen.dart` —
  sentences; leave them.
- Do not set `fontFeatures` globally in `ThemeData` — tabular digits look loose
  inside normal sentences, so it must stay per-widget.

## STOP if

- Any of the four `Text` widgets doesn't match its quoted excerpt.
- `theme.textTheme.bodyMedium` / `titleSmall` / `bodyLarge` is already being
  `.copyWith`-ed with `fontFeatures` at that spot.
- A check fails twice.

## When you're done

Start a game and roll a few times: the preview numbers in the active player's
column no longer twitch sideways as they change, and once players commit scores
the columns line up digit-for-digit. Open `lib/widgets/score_table.dart` to see
the change.
