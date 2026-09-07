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

  Widget subject() => MaterialApp(
        home: GameScreen(storage: const GameStorage(), random: Random(1)),
      );

  /// A tall viewport so the whole screen fits without scrolling.
  Future<void> pumpTall(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(subject());
  }

  testWidgets('starts on round 1 with 3 rolls', (tester) async {
    await tester.pumpWidget(subject());

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

    expect(find.text('Round 1 / 15'), findsOneWidget);
  });

  testWidgets('rolling spends a roll', (tester) async {
    await tester.pumpWidget(subject());

    await tester.tap(find.widgetWithText(FilledButton, 'Roll'));
    await tester.pumpAndSettle();

    expect(find.text('Rolls left: 2'), findsOneWidget);
  });

  testWidgets('committing a category advances the round', (tester) async {
    await pumpTall(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Roll'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category_chance')));
    await tester.pumpAndSettle();

    expect(find.text('Round 2 / 15'), findsOneWidget);
    expect(find.text('Rolls left: 3'), findsOneWidget);
  });

  testWidgets('finishing all 15 rounds saves a result and shows the summary',
      (tester) async {
    await pumpTall(tester);

    for (final category in ScoreCategory.values) {
      await tester.tap(find.widgetWithText(FilledButton, 'Roll'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('category_${category.name}')));
      await tester.pumpAndSettle();
    }

    expect(find.text('Game over'), findsOneWidget);
    expect(await GameStorage().loadHistory(), hasLength(1));
  });
}
