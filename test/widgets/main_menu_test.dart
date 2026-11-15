import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dice_zee/models/game_mode.dart';
import 'package:dice_zee/models/game_result.dart';
import 'package:dice_zee/models/score_card.dart';
import 'package:dice_zee/services/auth_service.dart';
import 'package:dice_zee/services/game_storage.dart';
import 'package:dice_zee/services/player_storage.dart';
import 'package:dice_zee/widgets/account_screen.dart';
import 'package:dice_zee/widgets/main_menu.dart';
import 'package:dice_zee/widgets/online_hub_screen.dart';
import 'package:dice_zee/widgets/play_menu_screen.dart';
import 'package:dice_zee/widgets/statistics_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Play opens the play menu', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('offline_button')));
    await tester.pumpAndSettle();

    expect(find.byType(PlayMenuScreen), findsOneWidget);
  });

  testWidgets('the main menu no longer starts a match directly', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Offline Game'), findsOneWidget);
    expect(find.text('Start'), findsNothing);
    expect(find.byType(SegmentedButton<int>), findsNothing);
  });

  testWidgets('the statistics button opens the statistics screen', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Statistics'));
    await tester.pumpAndSettle();

    expect(find.byType(StatisticsScreen), findsOneWidget);
  });

  testWidgets('Online opens the online hub', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MainMenuScreen(authServiceBuilder: () => _SignedOutAuth()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('online_button')));
    await tester.pumpAndSettle();

    expect(find.byType(OnlineHubScreen), findsOneWidget);
  });

  testWidgets('Play (online) comes before Offline Game', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Online Game'), findsNothing);
    final play = tester.getTopLeft(find.byKey(const ValueKey('online_button')));
    final offline = tester.getTopLeft(
      find.byKey(const ValueKey('offline_button')),
    );
    expect(play.dy, lessThan(offline.dy));
  });

  testWidgets('there is no Players entry any more', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Players'), findsNothing);
  });

  group('personal bests', () {
    GameResult game(GameMode mode, int mine, {int theirs = 0, int day = 1}) =>
        GameResult(
          playedAt: DateTime.utc(2026, 1, day),
          playerCount: 2,
          mode: mode,
          players: [
            PlayerScore(
              categoryScores: {
                for (final c in ScoreCategory.values) c: 0,
                ScoreCategory.chance: mine,
              },
              profileId: 'account_u1',
            ),
            PlayerScore(
              categoryScores: {
                for (final c in ScoreCategory.values) c: 0,
                ScoreCategory.chance: theirs,
              },
            ),
          ],
        );

    testWidgets("shows the signed-in account's best per mode, only for "
        'modes it has played', (tester) async {
      await const PlayerStorage().ensureAccountProfile('u1', 'Ada');
      const games = GameStorage();
      await games.saveResult(game(GameMode.standard, 20, theirs: 99, day: 1));
      await games.saveResult(game(GameMode.standard, 25, day: 2));
      await games.saveResult(game(GameMode.combined, 18, day: 3));

      await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Standard best · 25'), findsOneWidget);
      expect(find.text('Combined best · 18'), findsOneWidget);
      expect(find.byKey(const ValueKey('best_extended')), findsNothing);
    });

    testWidgets('shows nothing when signed out', (tester) async {
      await const GameStorage().saveResult(game(GameMode.standard, 25));

      await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('best_standard')), findsNothing);
    });

    testWidgets('ignores games the account did not play in', (tester) async {
      await const PlayerStorage().ensureAccountProfile('u1', 'Ada');
      await const GameStorage().saveResult(
        GameResult(
          playedAt: DateTime.utc(2026, 1, 1),
          playerCount: 2,
          players: [
            for (var i = 0; i < 2; i++)
              PlayerScore(
                categoryScores: {
                  for (final c in ScoreCategory.values) c: 0,
                  ScoreCategory.chance: 30,
                },
              ),
          ],
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('best_standard')), findsNothing);
    });
  });

  testWidgets('Account button opens the account screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MainMenuScreen(authServiceBuilder: () => _SignedOutAuth()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountScreen), findsOneWidget);
  });
}

class _SignedOutAuth implements AuthService {
  @override
  bool get appleSupported => false;
  @override
  AccountUser? get currentUser => null;
  @override
  Stream<AccountUser?> authStateChanges() => const Stream.empty();
  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> signInWithApple() async {}
  @override
  Future<void> deleteAccount(Future<void> Function(String uid) cleanup) async {}

  @override
  Future<void> signOut() async {}
}
