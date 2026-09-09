import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dice_zee/models/score_card.dart';
import 'package:dice_zee/widgets/score_table.dart';

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(width: 380, child: child),
        ),
      ),
    );

List<ScoreCard> cards(int n) => [for (var i = 0; i < n; i++) ScoreCard()];

void main() {
  testWidgets('renders a column header for every player', (tester) async {
    await tester.pumpWidget(_host(ScoreTable(
      cards: cards(3),
      currentPlayer: 0,
      currentDice: const [1, 2, 3, 4, 5],
      canCommit: false,
      onCommit: (_) {},
    )));

    expect(find.byKey(const ValueKey('col_header_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('col_header_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('col_header_2')), findsOneWidget);
    expect(find.byKey(const ValueKey('col_header_3')), findsNothing);
  });

  testWidgets('renders a row for every category plus a totals row',
      (tester) async {
    await tester.pumpWidget(_host(ScoreTable(
      cards: cards(2),
      currentPlayer: 0,
      currentDice: const [1, 2, 3, 4, 5],
      canCommit: false,
      onCommit: (_) {},
    )));

    for (final category in ScoreCategory.values) {
      expect(find.byKey(ValueKey('row_${category.name}')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('row_total')), findsOneWidget);
  });

  testWidgets("the current player's open cell previews and commits on tap",
      (tester) async {
    ScoreCategory? committed;
    await tester.pumpWidget(_host(ScoreTable(
      cards: cards(2),
      currentPlayer: 0,
      currentDice: const [3, 3, 3, 2, 2], // full house -> 25
      canCommit: true,
      onCommit: (c) => committed = c,
    )));

    final cell = find.byKey(const ValueKey('commit_fullHouse'));
    expect(
      find.descendant(of: cell, matching: find.text('25')),
      findsOneWidget,
    );

    await tester.ensureVisible(cell);
    await tester.tap(cell);
    expect(committed, ScoreCategory.fullHouse);
  });

  testWidgets('only the current player has committable cells', (tester) async {
    await tester.pumpWidget(_host(ScoreTable(
      cards: cards(3),
      currentPlayer: 1,
      currentDice: const [1, 2, 3, 4, 5],
      canCommit: true,
      onCommit: (_) {},
    )));

    // One committable cell per still-open category, all in player 1's column.
    expect(
      find.byKey(const ValueKey('commit_chance')),
      findsOneWidget,
    );
  });

  testWidgets('no cells are committable when canCommit is false',
      (tester) async {
    await tester.pumpWidget(_host(ScoreTable(
      cards: cards(2),
      currentPlayer: 0,
      currentDice: const [1, 2, 3, 4, 5],
      canCommit: false,
      onCommit: (_) {},
    )));

    expect(find.byKey(const ValueKey('commit_chance')), findsNothing);
  });

  testWidgets('a committed score is shown in that player\'s column',
      (tester) async {
    final list = cards(2);
    list[1].commit(ScoreCategory.chance, [6, 6, 6, 1, 1]); // 20

    await tester.pumpWidget(_host(ScoreTable(
      cards: list,
      currentPlayer: 0,
      currentDice: const [1, 1, 1, 1, 1],
      canCommit: true,
      onCommit: (_) {},
    )));

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('cell_1_chance')),
        matching: find.text('20'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the totals row shows each player total', (tester) async {
    final list = cards(2);
    list[0].commit(ScoreCategory.sixes, [6, 6, 6, 1, 1]); // 18
    list[1].commit(ScoreCategory.fullHouse, [2, 2, 2, 5, 5]); // 25

    await tester.pumpWidget(_host(ScoreTable(
      cards: list,
      currentPlayer: 0,
      currentDice: const [1, 2, 3, 4, 5],
      canCommit: false,
      onCommit: (_) {},
    )));

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('total_0')),
        matching: find.text('18'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('total_1')),
        matching: find.text('25'),
      ),
      findsOneWidget,
    );
  });
}
