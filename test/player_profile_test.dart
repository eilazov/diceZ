import 'package:flutter_test/flutter_test.dart';

import 'package:dice_zee/models/player_profile.dart';

void main() {
  test('round-trips through JSON', () {
    const profile = PlayerProfile(id: '123', name: 'Levon');

    final restored = PlayerProfile.fromJson(profile.toJson());

    expect(restored.id, '123');
    expect(restored.name, 'Levon');
  });

  test('equal id and name compare equal', () {
    expect(
      const PlayerProfile(id: '1', name: 'Levon'),
      const PlayerProfile(id: '1', name: 'Levon'),
    );
  });

  test('a different id is not equal', () {
    expect(
      const PlayerProfile(id: '1', name: 'Levon'),
      isNot(const PlayerProfile(id: '2', name: 'Levon')),
    );
  });

  test('linkedToAccount defaults to false and survives JSON', () {
    expect(const PlayerProfile(id: '1', name: 'A').linkedToAccount, isFalse);
    expect(
      PlayerProfile.fromJson(const {'id': '1', 'name': 'A'}).linkedToAccount,
      isFalse,
    );

    const linked = PlayerProfile(id: '1', name: 'A', linkedToAccount: true);
    expect(PlayerProfile.fromJson(linked.toJson()).linkedToAccount, isTrue);
  });
}
