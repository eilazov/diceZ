import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dice_zee/widgets/results_screen.dart';

void main() {
  testWidgets('falls back to seat labels when no names are given',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ResultsScreen(standings: [30, 45], winner: 1),
    ));

    expect(find.text('Player 2 wins!'), findsOneWidget);
    expect(find.text('Player 1'), findsOneWidget);
  });

  testWidgets('uses provided names when given', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ResultsScreen(
        standings: [30, 45],
        winner: 1,
        names: ['Levon', 'Anna'],
      ),
    ));

    expect(find.text('Anna wins!'), findsOneWidget);
    expect(find.text('Levon'), findsOneWidget);
  });

  testWidgets('Rematch pops ResultsAction.rematch', (tester) async {
    ResultsAction? popped;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            popped = await Navigator.of(context).push<ResultsAction>(
              MaterialPageRoute(
                builder: (_) =>
                    const ResultsScreen(standings: [30, 45], winner: 1),
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rematch_button')));
    await tester.pumpAndSettle();

    expect(popped, ResultsAction.rematch);
  });
}
