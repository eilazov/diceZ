import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:dice_zee/models/game_mode.dart';
import 'package:dice_zee/models/game_result.dart';
import 'package:dice_zee/services/account_cleanup.dart';
import 'package:dice_zee/services/cloud_store.dart';
import 'package:dice_zee/services/friend_service.dart';
import 'package:dice_zee/services/online_match_service.dart';

import 'support/in_memory_friend_store.dart';
import 'support/in_memory_online_match_store.dart';

class _Cloud implements CloudStore {
  bool deleted = false;

  @override
  Future<List<GameResult>> loadMatches() async => [];
  @override
  Future<void> saveMatches(List<GameResult> matches) async {}
  @override
  Future<void> deleteAllMatches() async => deleted = true;
}

void main() {
  late InMemoryFriendStore friendStore;
  late FriendService friends;
  late InMemoryOnlineMatchStore matchStore;
  late OnlineMatchService online;
  late _Cloud cloud;
  late AccountCleanup cleanup;

  setUp(() {
    friendStore = InMemoryFriendStore();
    friends = FriendService(friendStore, random: Random(3));
    matchStore = InMemoryOnlineMatchStore();
    online = OnlineMatchService(matchStore);
    cloud = _Cloud();
    cleanup = AccountCleanup(friends, online, (_) => cloud);
  });

  test(
    'removes the account from friends, requests and the code registry',
    () async {
      final ada = await friends.myProfile('a', 'Ada');
      final bob = await friends.myProfile('b', 'Bob');
      final cy = await friends.myProfile('c', 'Cy');
      final di = await friends.myProfile('d', 'Di');
      await friends.sendRequest(ada, bob.code);
      await friends.accept(bob, ada); // Ada and Bob are friends
      await friends.sendRequest(cy, ada.code); // incoming for Ada
      await friends.sendRequest(ada, di.code); // outgoing from Ada

      await cleanup.run('a');

      expect((await friends.load('b')).friends, isEmpty);
      expect((await friends.load('c')).outgoing, isEmpty);
      expect((await friends.load('d')).incoming, isEmpty);
      expect(await friendStore.findByCode(ada.code), isNull);
    },
  );

  test("deletes the account's online matches and cloud results", () async {
    final ada = await friends.myProfile('a', 'Ada');
    final bob = await friends.myProfile('b', 'Bob');
    final cy = await friends.myProfile('c', 'Cy');
    await online.challenge(ada, bob, GameMode.standard);
    await online.challenge(cy, ada, GameMode.standard);
    await online.challenge(cy, bob, GameMode.standard); // not Ada's

    await cleanup.run('a');

    expect(matchStore.matches.length, 1);
    expect(cloud.deleted, isTrue);
  });
}
