import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dice_zee/main.dart';

void main() {
  testWidgets('app boots to the game screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const DiceZeeApp());

    expect(find.widgetWithText(AppBar, 'Dice Zee'), findsOneWidget);
    expect(find.text('Round 1 / 15'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Roll'), findsOneWidget);
  });
}
