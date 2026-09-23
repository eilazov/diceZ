import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dice_zee/services/player_storage.dart';
import 'package:dice_zee/widgets/game_screen.dart';
import 'package:dice_zee/widgets/main_menu.dart';
import 'package:dice_zee/widgets/player_select_screen.dart';
import 'package:dice_zee/widgets/players_screen.dart';
import 'package:dice_zee/widgets/statistics_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('offers a 2, 3 and 4 player choice', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(SegmentedButton<int>, '2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.byKey(const ValueKey('start_button')), findsOneWidget);
  });

  testWidgets(
      'starting with no profiles registered opens the game with an all-guest lineup',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('3'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('start_button')));
    await tester.pumpAndSettle();

    final screen = tester.widget<GameScreen>(find.byType(GameScreen));
    expect(screen.lineup, [null, null, null]);
  });

  testWidgets(
      'starting with exactly one profile seats it first, no selection screen',
      (tester) async {
    const playerStorage = PlayerStorage();
    await playerStorage.addProfile('Levon');
    final levon = (await playerStorage.loadProfiles()).single;

    await tester.pumpWidget(const MaterialApp(
      home: MainMenuScreen(playerStorage: playerStorage),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start_button')));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerSelectScreen), findsNothing);
    final screen = tester.widget<GameScreen>(find.byType(GameScreen));
    expect(screen.lineup, [levon, null]);
  });

  testWidgets('starting with 2+ profiles opens the player select screen',
      (tester) async {
    const playerStorage = PlayerStorage();
    await playerStorage.addProfile('Levon');
    await playerStorage.addProfile('Anna');

    await tester.pumpWidget(const MaterialApp(
      home: MainMenuScreen(playerStorage: playerStorage),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start_button')));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerSelectScreen), findsOneWidget);
  });

  testWidgets('the statistics button opens the statistics screen',
      (tester) async {
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
}
