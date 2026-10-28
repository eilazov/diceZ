import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dice_zee/widgets/dice_zee_celebration.dart';
import 'package:dice_zee/widgets/pip_face.dart';

void main() {
  Widget subject({VoidCallback? onDone, int points = 100}) => MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          DiceZeeCelebration(
            face: 5,
            accent: Colors.teal,
            name: 'Ada',
            points: points,
            onDone: onDone ?? () {},
            random: Random(1),
          ),
        ],
      ),
    ),
  );

  testWidgets('shows the five dice, the title and the points', (tester) async {
    await tester.pumpWidget(subject(points: 50));
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(PipFace), findsNWidgets(5));
    for (final letter in 'DICEZE'.split('').toSet()) {
      expect(find.text(letter), findsWidgets);
    }
    expect(find.text('+50 POINTS'), findsOneWidget);
    expect(find.text('ADA ROLLED'), findsOneWidget);
  });

  testWidgets('is described to screen readers as one announcement', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(subject());
    await tester.pump(const Duration(seconds: 2));

    expect(
      find.bySemanticsLabel('Dice Zee! Ada rolled five 5s for 100 points'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('ignores touches', (tester) async {
    await tester.pumpWidget(subject());
    expect(
      find.descendant(
        of: find.byType(DiceZeeCelebration),
        matching: find.byType(IgnorePointer),
      ),
      findsWidgets,
    );
  });

  testWidgets('calls onDone once when the animation ends', (tester) async {
    var done = 0;
    await tester.pumpWidget(subject(onDone: () => done++));
    expect(done, 0);

    await tester.pump(DiceZeeCelebration.duration + const Duration(seconds: 1));
    expect(done, 1);
  });
}
