import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dice_zee/services/player_storage.dart';
import 'package:dice_zee/widgets/players_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storage = PlayerStorage();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget subject() => const MaterialApp(home: PlayersScreen(storage: storage));

  testWidgets('shows an empty state with no profiles', (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.text('No players yet.'), findsOneWidget);
  });

  testWidgets('adding a player shows it in the list', (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add_player_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('player_name_field')),
      'Levon',
    );
    await tester.tap(find.byKey(const ValueKey('save_player_name')));
    await tester.pumpAndSettle();

    expect(find.text('Levon'), findsOneWidget);
    expect(await storage.loadProfiles(), hasLength(1));
  });

  testWidgets('adding an empty name does nothing', (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add_player_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save_player_name')));
    await tester.pumpAndSettle();

    expect(await storage.loadProfiles(), isEmpty);
  });

  testWidgets('tapping a player renames it', (tester) async {
    await storage.addProfile('Levon');

    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Levon'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('player_name_field')),
      'Levon E.',
    );
    await tester.tap(find.byKey(const ValueKey('save_player_name')));
    await tester.pumpAndSettle();

    expect(find.text('Levon E.'), findsOneWidget);
    expect(find.text('Levon'), findsNothing);
    final profiles = await storage.loadProfiles();
    expect(profiles, hasLength(1));
    expect(profiles.single.name, 'Levon E.');
  });

  testWidgets('renaming to the same name is a no-op', (tester) async {
    await storage.addProfile('Levon');

    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Levon'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save_player_name')));
    await tester.pumpAndSettle();

    final profiles = await storage.loadProfiles();
    expect(profiles, hasLength(1));
    expect(profiles.single.name, 'Levon');
  });

  testWidgets('deleting a player removes it after confirming', (tester) async {
    await storage.addProfile('Levon');
    final id = (await storage.loadProfiles()).single.id;

    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('delete_$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.text('Levon'), findsNothing);
    expect(await storage.loadProfiles(), isEmpty);
  });

  testWidgets('cancelling delete leaves the profile untouched', (tester) async {
    await storage.addProfile('Levon');
    final id = (await storage.loadProfiles()).single.id;

    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('delete_$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Levon'), findsOneWidget);
    expect(await storage.loadProfiles(), hasLength(1));
  });
}
