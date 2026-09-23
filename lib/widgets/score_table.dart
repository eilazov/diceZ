import 'package:flutter/material.dart';

import '../models/score_card.dart';
import '../seat_palette.dart';

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

/// The six number categories (Ones..Sixes).
const List<ScoreCategory> _numberCategories = [
  ScoreCategory.ones,
  ScoreCategory.twos,
  ScoreCategory.threes,
  ScoreCategory.fours,
  ScoreCategory.fives,
  ScoreCategory.sixes,
];

/// The nine combination categories.
const List<ScoreCategory> _comboCategories = [
  ScoreCategory.onePair,
  ScoreCategory.twoPairs,
  ScoreCategory.threeOfAKind,
  ScoreCategory.fourOfAKind,
  ScoreCategory.fullHouse,
  ScoreCategory.smallStraight,
  ScoreCategory.largeStraight,
  ScoreCategory.yahtzee,
  ScoreCategory.chance,
];

/// The shared score sheet for every player: the 15 categories (grouped into
/// Numbers and Combos) plus a totals row, one column per player. The active
/// player's column carries their seat colour; while they can act, its
/// still-open cells preview the current dice and commit on tap.
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

  Color _seatColor() => SeatPalette.color(currentPlayer);

  @override
  Widget build(BuildContext context) {
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: {
        0: const IntrinsicColumnWidth(),
        for (var p = 0; p < cards.length; p++) p + 1: const FlexColumnWidth(),
      },
      children: [
        _headerRow(context),
        _sectionRow(context, 'Numbers', 'section_numbers'),
        for (final category in _numberCategories) _categoryRow(context, category),
        _subtotalRow(context),
        _sectionRow(context, 'Combos', 'section_combos'),
        for (final category in _comboCategories) _categoryRow(context, category),
        _totalsRow(context),
      ],
    );
  }

  TableRow _headerRow(BuildContext context) {
    final theme = Theme.of(context);
    final seat = _seatColor();
    return TableRow(
      children: [
        const SizedBox(height: 40),
        for (var p = 0; p < cards.length; p++)
          _Cell(
            key: ValueKey('col_header_$p'),
            highlightColor:
                p == currentPlayer ? seat.withValues(alpha: 0.14) : null,
            child: Text(
              SeatPalette.shortLabel(p),
              style: theme.textTheme.labelLarge?.copyWith(
                color: p == currentPlayer ? seat : null,
                fontWeight:
                    p == currentPlayer ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
      ],
    );
  }

  TableRow _sectionRow(BuildContext context, String label, String key) {
    final theme = Theme.of(context);
    return TableRow(
      children: [
        Padding(
          key: ValueKey(key),
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
          child: Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        for (var p = 0; p < cards.length; p++)
          _Cell(
            highlightColor: p == currentPlayer
                ? _seatColor().withValues(alpha: 0.14)
                : null,
            child: const SizedBox.shrink(),
          ),
      ],
    );
  }

  TableRow _categoryRow(BuildContext context, ScoreCategory category) {
    final theme = Theme.of(context);
    final openForCurrent = !cards[currentPlayer].isFilled(category);
    final seat = _seatColor();
    return TableRow(
      decoration: BoxDecoration(border: _rowRule(theme)),
      children: [
        Container(
          key: ValueKey('row_${category.name}'),
          color: openForCurrent ? seat.withValues(alpha: 0.10) : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            categoryShortLabel(category),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: openForCurrent ? null : theme.colorScheme.onSurfaceVariant,
              fontWeight: openForCurrent ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        for (var p = 0; p < cards.length; p++) _scoreCell(context, p, category),
      ],
    );
  }

  /// A hairline rule under a row, so each value lines up with its category.
  Border _rowRule(ThemeData theme) => Border(
        bottom: BorderSide(
          color: theme.dividerColor.withValues(alpha: 0.6),
          width: 0.5,
        ),
      );

  Widget _scoreCell(BuildContext context, int player, ScoreCategory category) {
    final theme = Theme.of(context);
    final card = cards[player];
    final isCurrent = player == currentPlayer;
    final seat = _seatColor();
    final columnWash = isCurrent ? seat.withValues(alpha: 0.14) : null;

    if (card.isFilled(category)) {
      return _Cell(
        key: ValueKey('cell_${player}_${category.name}'),
        highlightColor: columnWash,
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
        highlightColor: columnWash,
        onTap: () => onCommit(category),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: seat.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: seat.withValues(alpha: 0.55)),
          ),
          child: Text(
            '${ScoreCard.score(category, currentDice)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: seat,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      );
    }

    return _Cell(
      key: ValueKey('cell_${player}_${category.name}'),
      highlightColor: columnWash,
      child: const SizedBox.shrink(),
    );
  }

  TableRow _subtotalRow(BuildContext context) {
    final theme = Theme.of(context);
    int subtotal(ScoreCard card) => _numberCategories.fold(
          0,
          (sum, c) => sum + (card.scoreOf(c) ?? 0),
        );
    return TableRow(
      decoration: BoxDecoration(border: _rowRule(theme)),
      children: [
        Padding(
          key: const ValueKey('row_number_subtotal'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            'Sum 1–6',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        for (var p = 0; p < cards.length; p++)
          _Cell(
            key: ValueKey('subtotal_$p'),
            highlightColor: p == currentPlayer
                ? _seatColor().withValues(alpha: 0.14)
                : null,
            child: Text(
              '${subtotal(cards[p])}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
      ],
    );
  }

  TableRow _totalsRow(BuildContext context) {
    final theme = Theme.of(context);
    final seat = _seatColor();
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
            highlightColor:
                p == currentPlayer ? seat.withValues(alpha: 0.18) : null,
            child: Text(
              '${cards[p].total}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: p == currentPlayer ? seat : null,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
      ],
    );
  }
}

/// A single fixed-height table cell: centered content, optional column
/// wash, optional tap handler.
class _Cell extends StatelessWidget {
  const _Cell({
    super.key,
    required this.child,
    this.highlightColor,
    this.onTap,
  });

  final Widget child;
  final Color? highlightColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      height: 44,
      alignment: Alignment.center,
      color: highlightColor,
      child: child,
    );

    if (onTap != null) {
      content = InkWell(onTap: onTap, child: content);
    }
    return content;
  }
}
