import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dice_zee/models/game_mode.dart';
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

  Future<void> saveGame({String? profileId, GameMode? mode}) =>
      storage.saveResult(
        GameResult(
          playedAt: DateTime.utc(2026, 9, 7),
          playerCount: 2,
          mode: mode ?? GameMode.standard,
          players: [
            PlayerScore(
              categoryScores: {
                for (final c in ScoreCategory.values) c: 0,
                ScoreCategory.yahtzee: 100,
              },
              profileId: profileId,
              name: profileId == null ? null : 'Levon',
            ), // total 100, winner
            PlayerScore(
              categoryScores: {
                for (final c in ScoreCategory.values) c: 0,
                ScoreCategory.sixes: 30,
              },
            ), // total 30, guest
          ],
        ),
      );

  testWidgets('signed out: only the Everyone row', (tester) async {
    await saveGame();

    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets("the account row shows its own game and win counts", (
    tester,
  ) async {
    await playerStorage.ensureAccountProfile('u1', 'Levon');
    final levon = (await playerStorage.loadProfiles()).single;
    await saveGame(profileId: levon.id);

    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.text('Levon'), findsOneWidget);
    expect(find.text('1 games · 1 wins'), findsOneWidget);
  });

  testWidgets('the account row is hidden when it has no games in the mode', (
    tester,
  ) async {
    await playerStorage.ensureAccountProfile('u1', 'Levon');

    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.text('Levon'), findsNothing);
  });

  testWidgets('legacy manual profiles never get a row', (tester) async {
    SharedPreferences.setMockInitialValues({
      'dice_zee.players': '[{"id":"1","name":"Anna"}]',
    });
    await saveGame(profileId: '1');

    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.text('Anna'), findsNothing);
    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets('tapping Everyone opens its detail screen', (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('stats_everyone')));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerStatsScreen), findsOneWidget);
    expect(find.text('No games played yet.'), findsOneWidget);
  });

  group('game mode', () {
    GameResult played(GameMode mode, int day) => GameResult(
      playedAt: DateTime.utc(2026, 1, day),
      playerCount: 2,
      mode: mode,
      players: [
        PlayerScore(
          categoryScores: {for (final c in ScoreCategory.values) c: 0},
        ),
        PlayerScore(
          categoryScores: {for (final c in ScoreCategory.values) c: 0},
        ),
      ],
    );

    Finder everyoneGames(String text) => find.descendant(
      of: find.byKey(const ValueKey('stats_everyone')),
      matching: find.text(text),
    );

    testWidgets('defaults to the mode of the latest match', (tester) async {
      await storage.saveResult(played(GameMode.standard, 1));
      await storage.saveResult(played(GameMode.extended, 2));
      await storage.saveResult(played(GameMode.extended, 3));

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(everyoneGames('2 games'), findsOneWidget);
    });

    testWidgets('switching mode recounts games for that mode', (tester) async {
      await storage.saveResult(played(GameMode.standard, 1));
      await storage.saveResult(played(GameMode.extended, 2));
      await storage.saveResult(played(GameMode.extended, 3));

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Standard'));
      await tester.pumpAndSettle();

      expect(everyoneGames('1 games'), findsOneWidget);
    });

    testWidgets('the stats page opens for the selected mode', (tester) async {
      await storage.saveResult(played(GameMode.standard, 1));

      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('stats_everyone')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<PlayerStatsScreen>(find.byType(PlayerStatsScreen)).mode,
        GameMode.standard,
      );
    });
  });
}
