import 'dart:math';

/// A [Random] whose every die roll lands on [face] (1..6). For tests that need
/// a guaranteed Dice Zee.
class ConstantRandom implements Random {
  ConstantRandom(this.face);

  final int face;

  @override
  int nextInt(int max) => face - 1;

  @override
  double nextDouble() => 0.5;

  @override
  bool nextBool() => false;
}
