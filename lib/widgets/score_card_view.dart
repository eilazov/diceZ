import 'package:flutter/material.dart';

import '../models/score_card.dart';

/// Human-readable label for each score category.
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

/// The 15-row score sheet. Open rows preview what [currentDice] would score
/// (when [canCommit]) and commit on tap; filled rows show their locked score.
class ScoreCardView extends StatelessWidget {
  const ScoreCardView({
    super.key,
    required this.card,
    required this.currentDice,
    required this.canCommit,
    required this.onCommit,
  });

  final ScoreCard card;
  final List<int> currentDice;
  final bool canCommit;
  final ValueChanged<ScoreCategory> onCommit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final category in ScoreCategory.values)
          _CategoryRow(
            key: ValueKey('category_${category.name}'),
            label: categoryLabel(category),
            filledScore: card.scoreOf(category),
            previewScore:
                canCommit ? ScoreCard.score(category, currentDice) : null,
            onTap: (!card.isFilled(category) && canCommit)
                ? () => onCommit(category)
                : null,
          ),
        const Divider(height: 1),
        Padding(
          key: const ValueKey('score_total'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: Theme.of(context).textTheme.titleMedium),
              Text(
                '${card.total}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    super.key,
    required this.label,
    required this.filledScore,
    required this.previewScore,
    required this.onTap,
  });

  final String label;
  final int? filledScore;
  final int? previewScore;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFilled = filledScore != null;

    final Widget trailing;
    if (isFilled) {
      trailing = Text('$filledScore', style: theme.textTheme.bodyLarge);
    } else if (previewScore != null) {
      trailing = Text(
        '$previewScore',
        style: theme.textTheme.bodyLarge?.copyWith(color: theme.disabledColor),
      );
    } else {
      trailing = Text('–', style: TextStyle(color: theme.disabledColor));
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: isFilled ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
