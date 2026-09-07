import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dice_zee/models/score_card.dart';
import 'package:dice_zee/services/game_storage.dart';
import 'package:dice_zee/widgets/game_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget subject({int playerCount = 2}) => MaterialApp(
        home: GameScreen(
          playerCount: playerCount,
          storage: const GameStorage(),
          random: Random(1),
        ),
      );

  /// A tall viewport so the whole screen fits without scrolling.
  Future<void> pumpTall(WidgetTester tester, {int playerCount = 2}) async {
    await tester.binding.setSurfaceSize(const Size(900, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(subject(playerCount: playerCount));
  }

  testWidgets('opens on player 1, round 1, with 3 rolls', (tester) async {
    await tester.pumpWidget(subject());

    expect(find.text("Player 1's turn"), findsOneWidget);
    expect(find.text('Round 1 / 15'), findsOneWidget);
    expect(find.text('Rolls left: 3'), findsOneWidget);
  });

  testWidgets('the score card is inert until the first roll', (tester) async {
    await tester.pumpWidget(subject());

    await tester.tap(
      find.byKey(const ValueKey('category_chance')),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(find.text("Player 1's turn"), findsOneWidget);
  });

  testWidgets('rolling spends a roll', (tester) async {
    await tester.pumpWidget(subject());

    await tester.tap(find.widgetWithText(FilledButton, 'Roll'));
    await tester.pumpAndSettle();

    expect(find.text('Rolls left: 2'), findsOneWidget);
  });

  testWidgets('committing passes the turn to the next player', (tester) async {
    await pumpTall(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Roll'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category_chance')));
    await tester.pumpAndSettle();

    expect(find.text("Player 2's turn"), findsOneWidget);
    expect(find.text('Round 1 / 15'), findsOneWidget);
    expect(find.text('Rolls left: 3'), findsOneWidget);
  });

  testWidgets('finishing the match saves a result and shows the summary',
      (tester) async {
    await pumpTall(tester);

    for (var round = 0; round < ScoreCategory.values.length; round++) {
      final category = ScoreCategory.values[round];
      for (var player = 0; player < 2; player++) {
        await tester.tap(find.widgetWithText(FilledButton, 'Roll'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('category_${category.name}')));
        await tester.pumpAndSettle();
      }
    }

    expect(find.text('Game over'), findsOneWidget);
    final history = await const GameStorage().loadHistory();
    expect(history, hasLength(1));
    expect(history.single.playerCount, 2);
  });
}
