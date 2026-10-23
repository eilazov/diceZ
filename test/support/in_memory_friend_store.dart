import 'dart:math';

import 'package:dice_zee/models/friend_code.dart';
import 'package:dice_zee/models/friend_profile.dart';
import 'package:dice_zee/services/friend_store.dart';

class InMemoryFriendStore implements FriendStore {
  final profiles = <String, FriendProfile>{};
  final _friends = <String, Map<String, FriendProfile>>{};
  final _incoming = <String, Map<String, FriendProfile>>{};
  final _outgoing = <String, Map<String, FriendProfile>>{};

  Map<String, FriendProfile> _m(
    Map<String, Map<String, FriendProfile>> table,
    String uid,
  ) => table.putIfAbsent(uid, () => {});

  @override
  Future<FriendProfile> ensureProfile(
    String uid,
    String name,
    Random random,
  ) async {
    final existing = profiles[uid];
    if (existing != null) return existing;
    String code;
    do {
      code = FriendCode.generate(random);
    } while (profiles.values.any((p) => p.code == code));
    return profiles[uid] = FriendProfile(uid: uid, name: name, code: code);
  }

  @override
  Future<FriendProfile?> findByCode(String code) async {
    for (final p in profiles.values) {
      if (p.code == code) return p;
    }
    return null;
  }

  @override
  Future<List<FriendProfile>> friends(String uid) async =>
      _m(_friends, uid).values.toList();

  @override
  Future<List<FriendProfile>> incoming(String uid) async =>
      _m(_incoming, uid).values.toList();

  @override
  Future<List<FriendProfile>> outgoing(String uid) async =>
      _m(_outgoing, uid).values.toList();

  @override
  Future<void> sendRequest(FriendProfile from, FriendProfile to) async {
    _m(_incoming, to.uid)[from.uid] = from;
    _m(_outgoing, from.uid)[to.uid] = to;
  }

  @override
  Future<void> accept(FriendProfile me, FriendProfile from) async {
    _m(_incoming, me.uid).remove(from.uid);
    _m(_outgoing, from.uid).remove(me.uid);
    _m(_friends, me.uid)[from.uid] = from;
    _m(_friends, from.uid)[me.uid] = me;
  }

  @override
  Future<void> decline(String myUid, String fromUid) async {
    _m(_incoming, myUid).remove(fromUid);
    _m(_outgoing, fromUid).remove(myUid);
  }

  @override
  Future<void> cancel(String myUid, String toUid) async {
    _m(_outgoing, myUid).remove(toUid);
    _m(_incoming, toUid).remove(myUid);
  }

  @override
  Future<void> remove(String myUid, String friendUid) async {
    _m(_friends, myUid).remove(friendUid);
    _m(_friends, friendUid).remove(myUid);
  }
}
