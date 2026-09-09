import 'package:flutter/material.dart';

/// The pip pattern for a die face value 1..6, drawn as filled circles.
///
/// Fills a [size]×[size] box; [color] is the pip colour. Used by the dice in
/// play and as a small glyph elsewhere.
class PipFace extends StatelessWidget {
  const PipFace({
    super.key,
    required this.value,
    required this.color,
    this.size = 56,
  });

  final int value;
  final Color color;
  final double size;

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
    final pips = _layout[value] ?? const <Alignment>[];
    final pip = size * 0.16;
    return SizedBox(
      width: size,
      height: size,
      child: Padding(
        padding: EdgeInsets.all(size * 0.18),
        child: Stack(
          children: [
            for (final a in pips)
              Align(
                alignment: a,
                child: Container(
                  width: pip,
                  height: pip,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
