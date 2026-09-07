import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dice_zee/models/score_card.dart';
import 'package:dice_zee/widgets/score_card_view.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('renders one row per category', (tester) async {
    await tester.pumpWidget(_host(ScoreCardView(
      card: ScoreCard(),
      currentDice: const [1, 2, 3, 4, 5],
      canCommit: false,
      onCommit: (_) {},
    )));

    for (final category in ScoreCategory.values) {
      expect(find.byKey(ValueKey('category_${category.name}')), findsOneWidget);
    }
  });

  testWidgets('tapping an open category commits it when canCommit', (tester) async {
    ScoreCategory? committed;
    await tester.pumpWidget(_host(ScoreCardView(
      card: ScoreCard(),
      currentDice: const [3, 3, 3, 2, 2],
      canCommit: true,
      onCommit: (c) => committed = c,
    )));

    await tester.tap(find.byKey(const ValueKey('category_fullHouse')));
    expect(committed, ScoreCategory.fullHouse);
  });

  testWidgets('a filled category is not tappable and shows its score',
      (tester) async {
    ScoreCategory? committed;
    final card = ScoreCard()..commit(ScoreCategory.chance, [4, 4, 4, 4, 4]);

    await tester.pumpWidget(_host(ScoreCardView(
      card: card,
      currentDice: const [1, 1, 1, 1, 1],
      canCommit: true,
      onCommit: (c) => committed = c,
    )));

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('category_chance')),
        matching: find.text('20'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('category_chance')),
      warnIfMissed: false,
    );
    expect(committed, isNull);
  });

  testWidgets('open categories are inert when canCommit is false', (tester) async {
    ScoreCategory? committed;
    await tester.pumpWidget(_host(ScoreCardView(
      card: ScoreCard(),
      currentDice: const [1, 2, 3, 4, 5],
      canCommit: false,
      onCommit: (c) => committed = c,
    )));

    await tester.tap(
      find.byKey(const ValueKey('category_chance')),
      warnIfMissed: false,
    );
    expect(committed, isNull);
  });

  testWidgets('shows the running total', (tester) async {
    final card = ScoreCard()..commit(ScoreCategory.sixes, [6, 6, 6, 1, 1]);

    await tester.pumpWidget(_host(ScoreCardView(
      card: card,
      currentDice: const [1, 2, 3, 4, 5],
      canCommit: false,
      onCommit: (_) {},
    )));

    expect(find.byKey(const ValueKey('score_total')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('score_total')),
        matching: find.text('18'),
      ),
      findsOneWidget,
    );
  });
}
