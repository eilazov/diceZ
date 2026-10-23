import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dice_zee/models/game_mode.dart';
import 'package:dice_zee/models/game_result.dart';
import 'package:dice_zee/models/score_card.dart';
import 'package:dice_zee/services/auth_service.dart';
import 'package:dice_zee/services/game_storage.dart';
import 'package:dice_zee/widgets/account_screen.dart';
import 'package:dice_zee/widgets/main_menu.dart';
import 'package:dice_zee/widgets/play_menu_screen.dart';
import 'package:dice_zee/widgets/players_screen.dart';
import 'package:dice_zee/widgets/statistics_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Play opens the play menu', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('play_button')));
    await tester.pumpAndSettle();

    expect(find.byType(PlayMenuScreen), findsOneWidget);
  });

  testWidgets('the main menu no longer starts a match directly', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Play'), findsOneWidget);
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

  testWidgets('the players button opens the players screen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Players'));
    await tester.pumpAndSettle();

    expect(find.byType(PlayersScreen), findsOneWidget);
  });

  testWidgets('shows the best game per mode that has been played', (
    tester,
  ) async {
    GameResult game(GameMode mode, int chance) => GameResult(
      playedAt: DateTime.utc(2026, 1, chance),
      playerCount: 1,
      mode: mode,
      players: [
        PlayerScore(
          categoryScores: {
            for (final c in ScoreCategory.values) c: 0,
            ScoreCategory.chance: chance,
          },
        ),
      ],
    );
    await const GameStorage().saveResult(game(GameMode.standard, 20));
    await const GameStorage().saveResult(game(GameMode.standard, 25));

    await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Standard best · 25'), findsOneWidget);
    expect(find.byKey(const ValueKey('best_extended')), findsNothing);
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
  Future<void> signOut() async {}
}
