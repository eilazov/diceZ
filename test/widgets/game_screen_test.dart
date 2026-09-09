import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dice_zee/models/score_card.dart';
import 'package:dice_zee/services/game_storage.dart';
import 'package:dice_zee/widgets/game_screen.dart';
import 'package:dice_zee/widgets/results_screen.dart';

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

  final rollButton = find.byKey(const ValueKey('roll_button'));
  final handoffReady = find.byKey(const ValueKey('handoff_ready'));

  Future<void> rollAndCommit(WidgetTester tester, ScoreCategory category) async {
    await tester.tap(rollButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('commit_${category.name}')));
    await tester.pumpAndSettle();
    if (handoffReady.evaluate().isNotEmpty) {
      await tester.tap(handoffReady);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('opens on player 1, round 1, with 3 rolls', (tester) async {
    await tester.pumpWidget(subject());

    expect(find.text('Player 1'), findsOneWidget);
    expect(find.text('Round 1 / 15'), findsOneWidget);
    expect(find.bySemanticsLabel('3 rolls left'), findsOneWidget);
  });

  testWidgets('no category is committable until the first roll', (tester) async {
    await tester.pumpWidget(subject());

    expect(find.byKey(const ValueKey('commit_chance')), findsNothing);
    expect(find.text('Player 1'), findsOneWidget);
  });

  testWidgets('rolling spends a roll', (tester) async {
    await tester.pumpWidget(subject());

    await tester.tap(rollButton);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('2 rolls left'), findsOneWidget);
  });

  testWidgets('committing shows a handoff cover, then the next turn',
      (tester) async {
    await pumpTall(tester);

    await tester.tap(rollButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('commit_chance')));
    await tester.pumpAndSettle();

    // The next player is behind a handoff cover until they tap "Start turn".
    expect(find.byKey(const ValueKey('handoff_seat')), findsOneWidget);
    await tester.tap(handoffReady);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('handoff_seat')), findsNothing);
    expect(find.text('Player 2'), findsOneWidget);
    expect(find.text('Round 1 / 15'), findsOneWidget);
    expect(find.bySemanticsLabel('3 rolls left'), findsOneWidget);
  });

  testWidgets('lays out on a phone-sized screen with 4 players, no overflow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(subject(playerCount: 4));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('roll_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('total_3')), findsOneWidget);
  });

  testWidgets('every player total is visible in the shared table',
      (tester) async {
    await pumpTall(tester, playerCount: 3);

    expect(find.byKey(const ValueKey('total_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('total_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('total_2')), findsOneWidget);
  });

  testWidgets('finishing the match saves a result and shows the results screen',
      (tester) async {
    await pumpTall(tester);

    for (final category in ScoreCategory.values) {
      for (var player = 0; player < 2; player++) {
        await rollAndCommit(tester, category);
      }
    }

    expect(find.byType(ResultsScreen), findsOneWidget);
    expect(find.text('Rematch'), findsOneWidget);

    final history = await const GameStorage().loadHistory();
    expect(history, hasLength(1));
    expect(history.single.playerCount, 2);
  });

  testWidgets('Rematch from the results screen starts a fresh match',
      (tester) async {
    await pumpTall(tester);

    for (final category in ScoreCategory.values) {
      for (var player = 0; player < 2; player++) {
        await rollAndCommit(tester, category);
      }
    }

    await tester.tap(find.byKey(const ValueKey('rematch_button')));
    await tester.pumpAndSettle();

    expect(find.byType(ResultsScreen), findsNothing);
    expect(find.text('Player 1'), findsOneWidget);
    expect(find.text('Round 1 / 15'), findsOneWidget);
  });
}
