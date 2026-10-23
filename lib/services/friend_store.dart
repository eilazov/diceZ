import 'dart:math';

import '../models/friend_profile.dart';

/// Remote friend data. Plain interface so [FriendService] can be tested
/// without Firebase.
abstract class FriendStore {
  /// The account's public profile, creating it (with a fresh unique code) on
  /// first use.
  Future<FriendProfile> ensureProfile(String uid, String name, Random random);

  Future<FriendProfile?> findByCode(String code);

  Future<List<FriendProfile>> friends(String uid);
  Future<List<FriendProfile>> incoming(String uid);
  Future<List<FriendProfile>> outgoing(String uid);

  Future<void> sendRequest(FriendProfile from, FriendProfile to);

  /// [me] accepts the request from [from]; both become friends.
  Future<void> accept(FriendProfile me, FriendProfile from);

  Future<void> decline(String myUid, String fromUid);
  Future<void> cancel(String myUid, String toUid);
  Future<void> remove(String myUid, String friendUid);
}
