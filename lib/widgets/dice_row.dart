import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The five dice in play. Tap a die to hold or release it (when [canHold]).
///
/// [rollCount] should change on every roll; each change retriggers a short
/// scale + rotation animation on the dice that are not held.
class DiceRow extends StatelessWidget {
  const DiceRow({
    super.key,
    required this.dice,
    required this.held,
    required this.canHold,
    required this.rollCount,
    required this.onToggleHold,
  });

  final List<int> dice;
  final List<bool> held;
  final bool canHold;
  final int rollCount;
  final ValueChanged<int> onToggleHold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < dice.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _Die(
              key: ValueKey('die_$i'),
              value: dice[i],
              held: held[i],
              animateKey: held[i] ? -1 : rollCount,
              onTap: canHold ? () => onToggleHold(i) : null,
            ),
          ),
      ],
    );
  }
}

class _Die extends StatelessWidget {
  const _Die({
    super.key,
    required this.value,
    required this.held,
    required this.animateKey,
    required this.onTap,
  });

  final int value;
  final bool held;
  final int animateKey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(animateKey),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        builder: (context, t, child) => Transform.rotate(
          angle: (1 - t) * math.pi / 6,
          child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
        ),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: held ? scheme.primaryContainer : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: held ? scheme.primary : scheme.outlineVariant,
              width: held ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              Center(child: _Pips(value: value, color: scheme.onSurface)),
              if (held)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Icon(Icons.push_pin, size: 14, color: scheme.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pip layout for a face value of 1..6.
class _Pips extends StatelessWidget {
  const _Pips({required this.value, required this.color});

  final int value;
  final Color color;

  static const Map<int, List<Alignment>> _layout = {
    1: [Alignment.center],
    2: [Alignment.topLeft, Alignment.bottomRight],
    3: [Alignment.topLeft, Alignment.center, Alignment.bottomRight],
    4: [
      Alignment.topLeft,
      Alignment.topRight,
      Alignment.bottomLeft,
      Alignment.bottomRight,
    ],
    5: [
      Alignment.topLeft,
      Alignment.topRight,
      Alignment.center,
      Alignment.bottomLeft,
      Alignment.bottomRight,
    ],
    6: [
      Alignment.topLeft,
      Alignment.topRight,
      Alignment.centerLeft,
      Alignment.centerRight,
      Alignment.bottomLeft,
      Alignment.bottomRight,
    ],
  };

  @override
  Widget build(BuildContext context) {
    final pips = _layout[value] ?? const [];
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Stack(
        children: [
          for (final a in pips)
            Align(
              alignment: a,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
  }
}
