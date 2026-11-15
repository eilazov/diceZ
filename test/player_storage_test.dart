import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dice_zee/services/player_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  const storage = PlayerStorage();

  test('loadProfiles is empty when nothing has been saved', () async {
    expect(await storage.loadProfiles(), isEmpty);
  });

  test('unparseable legacy entries are skipped, not thrown', () async {
    SharedPreferences.setMockInitialValues({
      'dice_zee.players': jsonEncode([
        {'foo': 'bar'}, // bad shape
        {'id': '1', 'name': 'Levon'},
      ]),
    });

    final profiles = await storage.loadProfiles();
    expect(profiles, hasLength(1));
    expect(profiles.single.name, 'Levon');
  });

  group('account profile', () {
    test('ensureAccountProfile adds a flagged profile', () async {
      await storage.ensureAccountProfile('uid1', 'Levon');

      final profiles = await storage.loadProfiles();
      expect(profiles, hasLength(1));
      expect(profiles.single.linkedToAccount, isTrue);
      expect(profiles.single.id, 'account_uid1');
      expect(profiles.single.name, 'Levon');
    });

    test(
      'ensureAccountProfile is idempotent and keeps the first name',
      () async {
        await storage.ensureAccountProfile('uid1', 'Levon');

        await storage.ensureAccountProfile('uid1', 'Other');

        final profiles = await storage.loadProfiles();
        expect(profiles, hasLength(1));
        expect(profiles.single.name, 'Levon');
      },
    );

    test('removeAccountProfile removes the account profile', () async {
      await storage.ensureAccountProfile('uid1', 'Levon');

      await storage.removeAccountProfile();

      expect(await storage.loadProfiles(), isEmpty);
    });
  });
}
