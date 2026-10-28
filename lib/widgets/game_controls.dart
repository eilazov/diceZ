import 'package:flutter/material.dart';

import 'dice_row.dart';

/// Whose turn it is, and how many rolls they have left (as pips).
class TurnHeader extends StatelessWidget {
  const TurnHeader({
    super.key,
    required this.name,
    required this.color,
    required this.rollsRemaining,
  });

  final String name;
  final Color color;
  final int rollsRemaining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: color.withValues(alpha: 0.10),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(
            name,
            key: const ValueKey('turn_header'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          RollsPips(remaining: rollsRemaining, color: color),
        ],
      ),
    );
  }
}

class RollsPips extends StatelessWidget {
  const RollsPips({super.key, required this.remaining, required this.color});

  final int remaining;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$remaining rolls left',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < remaining ? color : Colors.transparent,
                  border: Border.all(
                    color: i < remaining ? color : scheme.outline,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pinned bottom deck: the five dice plus the Roll button, in the thumb zone.
class ControlDeck extends StatelessWidget {
  const ControlDeck({
    super.key,
    required this.dice,
    required this.held,
    required this.canHold,
    required this.placeholder,
    required this.rollCount,
    required this.seatColor,
    required this.rollsRemaining,
    required this.canRoll,
    required this.awaitingCommit,
    required this.onRoll,
    required this.onToggleHold,
  });

  final List<int> dice;
  final List<bool> held;
  final bool canHold;
  final bool placeholder;
  final int rollCount;
  final Color seatColor;
  final int rollsRemaining;
  final bool canRoll;
  final bool awaitingCommit;
  final VoidCallback onRoll;
  final ValueChanged<int> onToggleHold;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final String label = canRoll
        ? 'Roll · $rollsRemaining left'
        : awaitingCommit
        ? 'Tap a category to score'
        : 'Roll';

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DiceRow(
                dice: dice,
                held: held,
                canHold: canHold,
                placeholder: placeholder,
                rollCount: rollCount,
                seatColor: seatColor,
                onToggleHold: onToggleHold,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('roll_button'),
                  onPressed: canRoll ? onRoll : null,
                  icon: const Icon(Icons.casino),
                  label: Text(label),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: canRoll ? seatColor : null,
                    foregroundColor: canRoll ? Colors.white : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
