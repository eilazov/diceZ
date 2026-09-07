import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dice_zee/widgets/game_screen.dart';
import 'package:dice_zee/widgets/main_menu.dart';
import 'package:dice_zee/widgets/statistics_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('offers 2, 3 and 4 player games', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));

    expect(find.text('2 Players'), findsOneWidget);
    expect(find.text('3 Players'), findsOneWidget);
    expect(find.text('4 Players'), findsOneWidget);
  });

  testWidgets('starting a 3 player game opens the game screen for 3',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));

    await tester.tap(find.text('3 Players'));
    await tester.pumpAndSettle();

    final screen = tester.widget<GameScreen>(find.byType(GameScreen));
    expect(screen.playerCount, 3);
  });

  testWidgets('the statistics button opens the statistics screen',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));

    await tester.tap(find.text('Statistics'));
    await tester.pumpAndSettle();

    expect(find.byType(StatisticsScreen), findsOneWidget);
  });
}
