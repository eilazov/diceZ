import 'package:flutter/material.dart';

import '../models/score_card.dart';

/// Full category label, for places with room (e.g. the statistics screen).
String categoryLabel(ScoreCategory category) => switch (category) {
      ScoreCategory.ones => 'Ones',
      ScoreCategory.twos => 'Twos',
      ScoreCategory.threes => 'Threes',
      ScoreCategory.fours => 'Fours',
      ScoreCategory.fives => 'Fives',
      ScoreCategory.sixes => 'Sixes',
      ScoreCategory.onePair => 'One pair',
      ScoreCategory.twoPairs => 'Two pairs',
      ScoreCategory.threeOfAKind => 'Three of a kind',
      ScoreCategory.fourOfAKind => 'Four of a kind',
      ScoreCategory.fullHouse => 'Full house',
      ScoreCategory.smallStraight => 'Small straight',
      ScoreCategory.largeStraight => 'Large straight',
      ScoreCategory.yahtzee => 'Dice Zee',
      ScoreCategory.chance => 'Chance',
    };

/// Compact category label, for the multi-column score table.
String categoryShortLabel(ScoreCategory category) => switch (category) {
      ScoreCategory.onePair => '1 pair',
      ScoreCategory.twoPairs => '2 pairs',
      ScoreCategory.threeOfAKind => '3 of a kind',
      ScoreCategory.fourOfAKind => '4 of a kind',
      ScoreCategory.smallStraight => 'Sm straight',
      ScoreCategory.largeStraight => 'Lg straight',
      _ => categoryLabel(category),
    };

/// The shared score sheet for every player: 15 category rows plus a totals row,
/// one column per player. The active player's column is highlighted; while they
/// can act, its still-open cells preview the current dice and commit on tap.
class ScoreTable extends StatelessWidget {
  const ScoreTable({
    super.key,
    required this.cards,
    required this.currentPlayer,
    required this.currentDice,
    required this.canCommit,
    required this.onCommit,
  });

  final List<ScoreCard> cards;
  final int currentPlayer;
  final List<int> currentDice;
  final bool canCommit;
  final ValueChanged<ScoreCategory> onCommit;

  @override
  Widget build(BuildContext context) {
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: {
        0: const IntrinsicColumnWidth(),
        for (var p = 0; p < cards.length; p++)
          p + 1: const FlexColumnWidth(),
      },
      children: [
        _headerRow(context),
        for (final category in ScoreCategory.values) _categoryRow(context, category),
        _totalsRow(context),
      ],
    );
  }

  TableRow _headerRow(BuildContext context) {
    final theme = Theme.of(context);
    return TableRow(
      children: [
        const SizedBox(height: 40),
        for (var p = 0; p < cards.length; p++)
          _Cell(
            key: ValueKey('col_header_$p'),
            highlight: p == currentPlayer,
            child: Text(
              'P${p + 1}',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight:
                    p == currentPlayer ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
      ],
    );
  }

  TableRow _categoryRow(BuildContext context, ScoreCategory category) {
    final theme = Theme.of(context);
    return TableRow(
      children: [
        Padding(
          key: ValueKey('row_${category.name}'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            categoryShortLabel(category),
            style: theme.textTheme.bodyMedium,
          ),
        ),
        for (var p = 0; p < cards.length; p++) _scoreCell(context, p, category),
      ],
    );
  }

  Widget _scoreCell(BuildContext context, int player, ScoreCategory category) {
    final theme = Theme.of(context);
    final card = cards[player];
    final isCurrent = player == currentPlayer;

    if (card.isFilled(category)) {
      return _Cell(
        key: ValueKey('cell_${player}_${category.name}'),
        highlight: isCurrent,
        child: Text(
          '${card.scoreOf(category)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );
    }

    if (isCurrent && canCommit) {
      return _Cell(
        key: ValueKey('commit_${category.name}'),
        highlight: true,
        onTap: () => onCommit(category),
        child: Text(
          '${ScoreCard.score(category, currentDice)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.disabledColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );
    }

    return _Cell(
      key: ValueKey('cell_${player}_${category.name}'),
      highlight: isCurrent,
      child: const SizedBox.shrink(),
    );
  }

  TableRow _totalsRow(BuildContext context) {
    final theme = Theme.of(context);
    return TableRow(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      children: [
        Padding(
          key: const ValueKey('row_total'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text('Total', style: theme.textTheme.titleSmall),
        ),
        for (var p = 0; p < cards.length; p++)
          _Cell(
            key: ValueKey('total_$p'),
            highlight: p == currentPlayer,
            child: Text(
              '${cards[p].total}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
      ],
    );
  }
}

/// A single fixed-height table cell: centered content, optional column
/// highlight, optional tap handler.
class _Cell extends StatelessWidget {
  const _Cell({
    super.key,
    required this.child,
    this.highlight = false,
    this.onTap,
  });

  final Widget child;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget content = Container(
      height: 40,
      alignment: Alignment.center,
      color: highlight ? scheme.primaryContainer.withValues(alpha: 0.35) : null,
      child: child,
    );

    if (onTap != null) {
      content = InkWell(onTap: onTap, child: content);
    }
    return content;
  }
}
