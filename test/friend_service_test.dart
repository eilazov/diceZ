import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:dice_zee/models/friend_profile.dart';
import 'package:dice_zee/services/friend_service.dart';

import 'support/in_memory_friend_store.dart';

void main() {
  late InMemoryFriendStore store;
  late FriendService service;
  late FriendProfile ada;
  late FriendProfile bob;

  setUp(() async {
    store = InMemoryFriendStore();
    service = FriendService(store, random: Random(3));
    ada = await service.myProfile('a', 'Ada');
    bob = await service.myProfile('b', 'Bob');
  });

  test('myProfile is stable and gives distinct codes', () async {
    expect((await service.myProfile('a', 'Ada')).code, ada.code);
    expect(ada.code, isNot(bob.code));
  });

  test('sending a request shows it as incoming/outgoing', () async {
    final result = await service.sendRequest(ada, bob.code);
    expect(result.status, AddFriendStatus.sent);
    expect(result.target, bob);
    expect((await service.load('b')).incoming, [ada]);
    expect((await service.load('a')).outgoing, [bob]);
  });

  test('code entry is forgiving about case and dashes', () async {
    final raw = '${bob.code.substring(0, 3)}-${bob.code.substring(3)}'
        .toLowerCase();
    final result = await service.sendRequest(ada, raw);
    expect(result.status, AddFriendStatus.sent);
  });

  test('invalid, unknown and own codes are rejected', () async {
    expect(
      (await service.sendRequest(ada, 'nope')).status,
      AddFriendStatus.invalidCode,
    );
    expect(
      (await service.sendRequest(ada, 'AAAAAA')).status,
      AddFriendStatus.notFound,
    );
    expect(
      (await service.sendRequest(ada, ada.code)).status,
      AddFriendStatus.self,
    );
  });

  test('duplicate request is rejected', () async {
    await service.sendRequest(ada, bob.code);
    expect(
      (await service.sendRequest(ada, bob.code)).status,
      AddFriendStatus.alreadyRequested,
    );
  });

  test('requesting someone who already requested you is flagged', () async {
    await service.sendRequest(bob, ada.code);
    expect(
      (await service.sendRequest(ada, bob.code)).status,
      AddFriendStatus.theyRequestedYou,
    );
  });

  test('accepting makes both sides friends and clears requests', () async {
    await service.sendRequest(ada, bob.code);
    await service.accept(bob, ada);
    final b = await service.load('b');
    final a = await service.load('a');
    expect(b.friends, [ada]);
    expect(a.friends, [bob]);
    expect(b.incoming, isEmpty);
    expect(a.outgoing, isEmpty);
    expect(
      (await service.sendRequest(ada, bob.code)).status,
      AddFriendStatus.alreadyFriends,
    );
  });

  test('declining clears the request without befriending', () async {
    await service.sendRequest(ada, bob.code);
    await service.decline('b', 'a');
    expect((await service.load('b')).incoming, isEmpty);
    expect((await service.load('a')).outgoing, isEmpty);
    expect((await service.load('b')).friends, isEmpty);
  });

  test('cancelling withdraws an outgoing request', () async {
    await service.sendRequest(ada, bob.code);
    await service.cancel('a', 'b');
    expect((await service.load('b')).incoming, isEmpty);
  });

  test('removing unfriends both sides', () async {
    await service.sendRequest(ada, bob.code);
    await service.accept(bob, ada);
    await service.remove('a', 'b');
    expect((await service.load('a')).friends, isEmpty);
    expect((await service.load('b')).friends, isEmpty);
  });
}
