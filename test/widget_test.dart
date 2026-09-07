import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dice_zee/main.dart';
import 'package:dice_zee/widgets/main_menu.dart';

void main() {
  testWidgets('app boots to the main menu', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const DiceZeeApp());

    expect(find.byType(MainMenuScreen), findsOneWidget);
    expect(find.text('2 Players'), findsOneWidget);
    expect(find.text('Statistics'), findsOneWidget);
  });
}
