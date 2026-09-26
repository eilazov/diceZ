import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dice_zee/services/player_storage.dart';
import 'package:dice_zee/widgets/game_screen.dart';
import 'package:dice_zee/widgets/player_select_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storage = PlayerStorage();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget subject(int playerCount) => MaterialApp(
        home: PlayerSelectScreen(playerCount: playerCount, storage: storage),
      );

  testWidgets('every seat defaults to Guest', (tester) async {
    await storage.addProfile('Levon');
    await storage.addProfile('Anna');

    await tester.pumpWidget(subject(2));
    await tester.pumpAndSettle();

    final guest0 =
        tester.widget<ChoiceChip>(find.byKey(const ValueKey('seat_0_guest')));
    final guest1 =
        tester.widget<ChoiceChip>(find.byKey(const ValueKey('seat_1_guest')));
    expect(guest0.selected, isTrue);
    expect(guest1.selected, isTrue);
  });

  testWidgets('picking a profile for one seat disables it on the other seats',
      (tester) async {
    await storage.addProfile('Levon');
    await storage.addProfile('Anna');
    final levon = (await storage.loadProfiles())[0];

    await tester.pumpWidget(subject(2));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('seat_0_${levon.id}')));
    await tester.pumpAndSettle();

    final seat0Chip =
        tester.widget<ChoiceChip>(find.byKey(ValueKey('seat_0_${levon.id}')));
    expect(seat0Chip.selected, isTrue);

    final seat1Chip =
        tester.widget<ChoiceChip>(find.byKey(ValueKey('seat_1_${levon.id}')));
    expect(seat1Chip.onSelected, isNull); // disabled: taken by seat 0
  });

  testWidgets('Start match opens the game with the chosen lineup',
      (tester) async {
    await storage.addProfile('Levon');
    await storage.addProfile('Anna');
    final levon = (await storage.loadProfiles())[0];

    await tester.pumpWidget(subject(2));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('seat_0_${levon.id}')));
    await tester.pumpAndSettle();
    // Seat 1 stays Guest.
    await tester.tap(find.byKey(const ValueKey('start_match_button')));
    await tester.pumpAndSettle();

    final game = tester.widget<GameScreen>(find.byType(GameScreen));
    expect(game.lineup, [levon, null]);
  });
}
