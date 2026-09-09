import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'pip_face.dart';

/// The five dice in play. Tap a die to hold or release it (when [canHold]).
///
/// [rollCount] should change on every roll; each change replays a staggered
/// "tumble": the un-held dice hop, wobble, and churn through random faces
/// before settling on their rolled value. Held dice sit still.
class DiceRow extends StatefulWidget {
  const DiceRow({
    super.key,
    required this.dice,
    required this.held,
    required this.canHold,
    required this.rollCount,
    required this.onToggleHold,
    this.seatColor,
    this.placeholder = false,
    this.dieSize = 58,
  });

  final List<int> dice;
  final List<bool> held;
  final bool canHold;
  final int rollCount;
  final ValueChanged<int> onToggleHold;

  /// Identity colour of the active seat; tints held dice. Falls back to the
  /// theme's primary when null.
  final Color? seatColor;

  /// Before the first roll of a turn: render blank faces, not interactive.
  final bool placeholder;

  final double dieSize;

  @override
  State<DiceRow> createState() => _DiceRowState();
}

class _DiceRowState extends State<DiceRow> with SingleTickerProviderStateMixin {
  /// One full pass (including the last die's stagger) of the tumble.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
    value: 1, // start at rest — only a roll starts the animation
  );

  final math.Random _rng = math.Random();
  late List<List<int>> _reels = _freshReels();

  /// Fraction of the timeline each successive die is delayed by.
  static const double _stagger = 0.085;

  /// Fraction of a die's local progress spent churning faces before it lands.
  static const double _churn = 0.72;

  List<List<int>> _freshReels() => List.generate(
        widget.dice.length,
        (_) => List.generate(7, (_) => _rng.nextInt(6) + 1),
      );

  @override
  void didUpdateWidget(covariant DiceRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rollCount != oldWidget.rollCount) {
      _reels = _freshReels();
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Die [i]'s own 0..1 progress, offset by its stagger. 1 == at rest.
  double _localT(int i) {
    final span = 1 - _stagger * (widget.dice.length - 1);
    return ((_controller.value - _stagger * i) / span).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = widget.seatColor ?? scheme.primary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < widget.dice.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: GestureDetector(
              key: ValueKey('die_$i'),
              behavior: HitTestBehavior.opaque,
              onTap: widget.canHold ? () => widget.onToggleHold(i) : null,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final held = widget.held[i];
                  return _DieBox(
                    finalValue: widget.dice[i],
                    reel: _reels[i],
                    t: held ? 1.0 : _localT(i),
                    held: held,
                    placeholder: widget.placeholder,
                    accent: accent,
                    size: widget.dieSize,
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _DieBox extends StatelessWidget {
  const _DieBox({
    required this.finalValue,
    required this.reel,
    required this.t,
    required this.held,
    required this.placeholder,
    required this.accent,
    required this.size,
  });

  final int finalValue;
  final List<int> reel;
  final double t; // 0..1 local progress; 1 == at rest
  final bool held;
  final bool placeholder;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rolling = t > 0 && t < 1;

    final face = t >= _DiceRowState._churn
        ? finalValue
        : reel[(t / _DiceRowState._churn * reel.length)
            .floor()
            .clamp(0, reel.length - 1)];

    final hop = rolling ? -math.sin(t * math.pi) * size * 0.30 : 0.0;
    final rot = rolling ? math.sin(t * math.pi * 3) * (1 - t) * 0.32 : 0.0;

    final box = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: held
            ? accent.withValues(alpha: 0.16)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(
          color: held ? accent : scheme.outlineVariant,
          width: held ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: held ? 0.20 : 0.10),
            blurRadius: held ? 10 : 6,
            offset: Offset(0, held ? 4 : 2),
          ),
        ],
      ),
      child: placeholder
          ? const SizedBox.shrink()
          : Stack(
              children: [
                Center(
                  child: PipFace(
                    value: face,
                    color: scheme.onSurface,
                    size: size,
                  ),
                ),
                if (held)
                  Positioned(
                    top: 3,
                    right: 3,
                    child: Icon(Icons.push_pin, size: size * 0.24, color: accent),
                  ),
              ],
            ),
    );

    return Transform.translate(
      offset: Offset(0, hop),
      child: Transform.rotate(
        angle: rot,
        child: Transform.scale(scale: _scaleFor(t), child: box),
      ),
    );
  }

  /// Quick anticipation dip, grow through the tumble, small settle back.
  double _scaleFor(double t) {
    if (t <= 0 || t >= 1) return 1;
    if (t < 0.12) return 1 - (t / 0.12) * 0.12; // 1.00 -> 0.88
    if (t < 0.72) return 0.88 + ((t - 0.12) / 0.60) * 0.20; // 0.88 -> 1.08
    return 1.08 - ((t - 0.72) / 0.28) * 0.08; // 1.08 -> 1.00
  }
}
