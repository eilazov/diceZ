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

  test('addProfile appends a new profile with a generated id', () async {
    await storage.addProfile('Levon');

    final profiles = await storage.loadProfiles();
    expect(profiles, hasLength(1));
    expect(profiles.single.name, 'Levon');
    expect(profiles.single.id, isNotEmpty);
  });

  test('addProfile preserves insertion order', () async {
    await storage.addProfile('Levon');
    await storage.addProfile('Anna');

    final names = (await storage.loadProfiles()).map((p) => p.name).toList();
    expect(names, ['Levon', 'Anna']);
  });

  test('addProfile gives each profile a distinct id', () async {
    await storage.addProfile('Levon');
    await storage.addProfile('Anna');

    final ids = (await storage.loadProfiles()).map((p) => p.id).toList();
    expect(ids.toSet(), hasLength(2));
  });

  test('renameProfile updates only the matching profile', () async {
    await storage.addProfile('Levon');
    await storage.addProfile('Anna');
    final id = (await storage.loadProfiles()).first.id;

    await storage.renameProfile(id, 'Levon E.');

    final names = (await storage.loadProfiles()).map((p) => p.name).toList();
    expect(names, ['Levon E.', 'Anna']);
  });

  test('renameProfile is a no-op for an unknown id', () async {
    await storage.addProfile('Levon');

    await storage.renameProfile('missing', 'X');

    final names = (await storage.loadProfiles()).map((p) => p.name).toList();
    expect(names, ['Levon']);
  });

  test('deleteProfile removes only the matching profile', () async {
    await storage.addProfile('Levon');
    await storage.addProfile('Anna');
    final id = (await storage.loadProfiles()).first.id;

    await storage.deleteProfile(id);

    final names = (await storage.loadProfiles()).map((p) => p.name).toList();
    expect(names, ['Anna']);
  });

  test('deleteProfile is a no-op for an unknown id', () async {
    await storage.addProfile('Levon');

    await storage.deleteProfile('missing');

    final names = (await storage.loadProfiles()).map((p) => p.name).toList();
    expect(names, ['Levon']);
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
}
