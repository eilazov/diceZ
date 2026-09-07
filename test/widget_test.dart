import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dice_zee/main.dart';

void main() {
  testWidgets('app boots without error', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const DiceZeeApp());

    expect(find.widgetWithText(AppBar, 'Dice Zee'), findsOneWidget);
  });
}
