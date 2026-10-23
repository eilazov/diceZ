import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dice_zee/models/game_mode.dart';
import 'package:dice_zee/services/player_storage.dart';
import 'package:dice_zee/widgets/game_screen.dart';
import 'package:dice_zee/widgets/play_menu_screen.dart';
import 'package:dice_zee/widgets/player_select_screen.dart';

/// The play menu is taller than the default 800x600 test surface.
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('offers a 2, 3 and 4 player choice', (tester) async {
    _tall(tester);
    await tester.pumpWidget(const MaterialApp(home: PlayMenuScreen()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(SegmentedButton<int>, '2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.byKey(const ValueKey('start_button')), findsOneWidget);
  });

  testWidgets(
    'starting with no profiles registered opens the game with an all-guest lineup',
    (tester) async {
      _tall(tester);
      await tester.pumpWidget(const MaterialApp(home: PlayMenuScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('3'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('start_button')));
      await tester.pumpAndSettle();

      final screen = tester.widget<GameScreen>(find.byType(GameScreen));
      expect(screen.lineup, [null, null, null]);
    },
  );

  testWidgets(
    'starting with exactly one profile seats it first, no selection screen',
    (tester) async {
      _tall(tester);
      const playerStorage = PlayerStorage();
      await playerStorage.addProfile('Levon');
      final levon = (await playerStorage.loadProfiles()).single;

      await tester.pumpWidget(
        const MaterialApp(home: PlayMenuScreen(playerStorage: playerStorage)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('start_button')));
      await tester.pumpAndSettle();

      expect(find.byType(PlayerSelectScreen), findsNothing);
      final screen = tester.widget<GameScreen>(find.byType(GameScreen));
      expect(screen.lineup, [levon, null]);
    },
  );

  testWidgets('starting with 2+ profiles opens the player select screen', (
    tester,
  ) async {
    _tall(tester);
    const playerStorage = PlayerStorage();
    await playerStorage.addProfile('Levon');
    await playerStorage.addProfile('Anna');

    await tester.pumpWidget(
      const MaterialApp(home: PlayMenuScreen(playerStorage: playerStorage)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start_button')));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerSelectScreen), findsOneWidget);
  });

  testWidgets('offers a mode choice, standard selected by default', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PlayMenuScreen()));
    await tester.pumpAndSettle();

    final selector = tester.widget<SegmentedButton<GameMode>>(
      find.byKey(const ValueKey('mode_selector')),
    );
    expect(selector.selected, {GameMode.standard});
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('Extended'), findsOneWidget);
    expect(find.byKey(const ValueKey('rules_standard')), findsOneWidget);
  });

  testWidgets('switching mode swaps the rules summary', (tester) async {
    _tall(tester);
    await tester.pumpWidget(const MaterialApp(home: PlayMenuScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Extended'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('rules_extended')), findsOneWidget);
    expect(find.byKey(const ValueKey('rules_standard')), findsNothing);
  });

  testWidgets('the chosen mode reaches the game', (tester) async {
    _tall(tester);
    await tester.pumpWidget(const MaterialApp(home: PlayMenuScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Extended'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('start_button')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<GameScreen>(find.byType(GameScreen)).mode,
      GameMode.extended,
    );
  });

  testWidgets('standard is the default mode of a started game', (tester) async {
    _tall(tester);
    await tester.pumpWidget(const MaterialApp(home: PlayMenuScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start_button')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<GameScreen>(find.byType(GameScreen)).mode,
      GameMode.standard,
    );
    expect(find.text('Round 1 / 13'), findsOneWidget);
  });

  testWidgets('the mode is passed on to the player select screen', (
    tester,
  ) async {
    const playerStorage = PlayerStorage();
    await playerStorage.addProfile('Levon');
    await playerStorage.addProfile('Anna');
    await tester.pumpWidget(
      const MaterialApp(home: PlayMenuScreen(playerStorage: playerStorage)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Extended'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('start_button')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<PlayerSelectScreen>(find.byType(PlayerSelectScreen)).mode,
      GameMode.extended,
    );
  });
}
