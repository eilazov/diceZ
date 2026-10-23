import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:dice_zee/models/friend_code.dart';

void main() {
  test('generate makes a 6-char code from the unambiguous alphabet', () {
    final code = FriendCode.generate(Random(1));
    expect(code, hasLength(FriendCode.length));
    for (final c in code.split('')) {
      expect(FriendCode.alphabet, contains(c));
    }
  });

  test('generate is deterministic for a seeded Random', () {
    expect(FriendCode.generate(Random(7)), FriendCode.generate(Random(7)));
  });

  test('alphabet leaves out look-alike characters', () {
    for (final c in ['0', 'O', '1', 'I']) {
      expect(FriendCode.alphabet, isNot(contains(c)));
    }
  });

  test('normalize uppercases and strips spaces and dashes', () {
    expect(FriendCode.normalize(' k7m-2qx '), 'K7M2QX');
  });

  test('normalize rejects wrong length or characters', () {
    expect(FriendCode.normalize('K7M2Q'), isNull);
    expect(FriendCode.normalize('K7M2QXZ'), isNull);
    expect(FriendCode.normalize('K7M2Q0'), isNull);
    expect(FriendCode.normalize(''), isNull);
  });
}
