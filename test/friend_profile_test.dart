import 'package:flutter_test/flutter_test.dart';

import 'package:dice_zee/models/friend_profile.dart';

void main() {
  test('JSON round-trips', () {
    const p = FriendProfile(uid: 'u1', name: 'Ada', code: 'K7M2QX');
    expect(FriendProfile.fromJson(p.toJson()), p);
  });
}
