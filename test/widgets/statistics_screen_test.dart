import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dice_zee/models/game_result.dart';
import 'package:dice_zee/models/score_card.dart';
import 'package:dice_zee/services/game_storage.dart';
import 'package:dice_zee/services/player_storage.dart';
import 'package:dice_zee/widgets/player_stats_screen.dart';
import 'package:dice_zee/widgets/statistics_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  const storage = GameStorage();
  const playerStorage = PlayerStorage();

  Widget subject() => const MaterialApp(
        home: StatisticsScreen(storage: storage, playerStorage: playerStorage),
      );

  testWidgets('always lists an Everyone row', (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('stats_everyone')), findsOneWidget);
    expect(find.text('0 games'), findsOneWidget);
  });

  testWidgets('lists one row per registered profile', (tester) async {
    await playerStorage.addProfile('Levon');
    await playerStorage.addProfile('Anna');

    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.text('Levon'), findsOneWidget);
    expect(find.text('Anna'), findsOneWidget);
  });

  testWidgets("a profile row shows its own game and win counts",
      (tester) async {
    await playerStorage.addProfile('Levon');
    final levon = (await playerStorage.loadProfiles()).single;

    await storage.saveResult(GameResult(
      playedAt: DateTime.utc(2026, 9, 7),
      playerCount: 2,
      players: [
        PlayerScore(
          categoryScores: {
            for (final c in ScoreCategory.values) c: 0,
            ScoreCategory.yahtzee: 100,
          },
          profileId: levon.id,
          name: levon.name,
        ), // total 100, winner
        PlayerScore(categoryScores: {
          for (final c in ScoreCategory.values) c: 0,
          ScoreCategory.sixes: 30,
        }), // total 30, guest
      ],
    ));

    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.text('1 games · 1 wins'), findsOneWidget);
  });

  testWidgets('tapping Everyone opens its detail screen', (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('stats_everyone')));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerStatsScreen), findsOneWidget);
    expect(find.text('No games played yet.'), findsOneWidget);
  });
}
