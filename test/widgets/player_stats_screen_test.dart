import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dice_zee/models/game_result.dart';
import 'package:dice_zee/models/score_card.dart';
import 'package:dice_zee/services/game_storage.dart';
import 'package:dice_zee/widgets/player_stats_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  const storage = GameStorage();

  testWidgets('shows an empty state when no games have been played',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: PlayerStatsScreen(title: 'Everyone', storage: storage),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No games played yet.'), findsOneWidget);
  });

  testWidgets('Everyone shows Games played and Average score, no Wins card',
      (tester) async {
    await storage.saveResult(GameResult(
      playedAt: DateTime.utc(2026, 9, 7),
      playerCount: 2,
      players: [
        PlayerScore(categoryScores: {
          for (final c in ScoreCategory.values) c: 0,
          ScoreCategory.yahtzee: 100,
        }),
        PlayerScore(categoryScores: {
          for (final c in ScoreCategory.values) c: 0,
          ScoreCategory.sixes: 30,
        }),
      ],
    ));

    await tester.binding.setSurfaceSize(const Size(800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(
      home: PlayerStatsScreen(title: 'Everyone', storage: storage),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('stat_games')), findsOneWidget);
    expect(find.byKey(const ValueKey('stat_avg')), findsOneWidget);
    expect(find.byKey(const ValueKey('stat_wins')), findsNothing);
  });

  testWidgets('a profile shows a Wins card scoped to its own games',
      (tester) async {
    await storage.saveResult(GameResult(
      playedAt: DateTime.utc(2026, 9, 7),
      playerCount: 2,
      players: [
        PlayerScore(
          categoryScores: {
            for (final c in ScoreCategory.values) c: 0,
            ScoreCategory.yahtzee: 100,
          },
          profileId: 'levon',
        ), // winner
        PlayerScore(categoryScores: {
          for (final c in ScoreCategory.values) c: 0,
          ScoreCategory.sixes: 30,
        }),
      ],
    ));

    await tester.binding.setSurfaceSize(const Size(800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(
      home: PlayerStatsScreen(
        title: 'Levon',
        profileId: 'levon',
        storage: storage,
      ),
    ));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('stat_wins')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });
}
