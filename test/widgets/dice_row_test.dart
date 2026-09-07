import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dice_zee/widgets/dice_row.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('tapping a die reports its index when holding is enabled',
      (tester) async {
    int? tapped;
    await tester.pumpWidget(_host(DiceRow(
      dice: const [1, 2, 3, 4, 5],
      held: const [false, false, false, false, false],
      canHold: true,
      rollCount: 1,
      onToggleHold: (i) => tapped = i,
    )));

    await tester.tap(find.byKey(const ValueKey('die_2')));
    expect(tapped, 2);
  });

  testWidgets('taps are ignored before the first roll', (tester) async {
    int? tapped;
    await tester.pumpWidget(_host(DiceRow(
      dice: const [1, 1, 1, 1, 1],
      held: const [false, false, false, false, false],
      canHold: false,
      rollCount: 0,
      onToggleHold: (i) => tapped = i,
    )));

    await tester.tap(find.byKey(const ValueKey('die_0')));
    expect(tapped, isNull);
  });

  testWidgets('a marker is shown for each held die', (tester) async {
    await tester.pumpWidget(_host(DiceRow(
      dice: const [1, 2, 3, 4, 5],
      held: const [true, false, true, false, false],
      canHold: true,
      rollCount: 1,
      onToggleHold: (_) {},
    )));

    expect(find.byIcon(Icons.push_pin), findsNWidgets(2));
  });
}
