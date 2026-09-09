import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dice_zee/models/game_result.dart';
import 'package:dice_zee/models/score_card.dart';
import 'package:dice_zee/services/game_storage.dart';
import 'package:dice_zee/widgets/statistics_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget subject() =>
      const MaterialApp(home: StatisticsScreen(storage: GameStorage()));

  testWidgets('shows an empty state when no games have been played',
      (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.text('No games played yet.'), findsOneWidget);
  });

  testWidgets('shows aggregates once a game is saved', (tester) async {
    await const GameStorage().saveResult(GameResult(
      playedAt: DateTime.utc(2026, 9, 7),
      playerCount: 2,
      players: [
        PlayerScore(categoryScores: {
          for (final c in ScoreCategory.values) c: 0,
          ScoreCategory.yahtzee: 100,
        }), // total 100
        PlayerScore(categoryScores: {
          for (final c in ScoreCategory.values) c: 0,
          ScoreCategory.sixes: 30,
        }), // total 30
      ],
    ));

    await tester.binding.setSurfaceSize(const Size(800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('stat_games')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('stat_avg')),
        matching: find.text('65.0'),
      ),
      findsOneWidget,
    );

    final yahtzeeRow = find.byKey(const ValueKey('best_yahtzee'));
    await tester.ensureVisible(yahtzeeRow);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: yahtzeeRow, matching: find.text('100')),
      findsOneWidget,
    );
  });
}
