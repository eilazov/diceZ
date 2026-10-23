import 'dart:math';

import '../models/friend_code.dart';
import '../models/friend_profile.dart';
import 'friend_store.dart';

enum AddFriendStatus {
  sent,
  invalidCode,
  notFound,
  self,
  alreadyFriends,
  alreadyRequested,
  theyRequestedYou,
}

class AddFriendResult {
  const AddFriendResult(this.status, [this.target]);

  final AddFriendStatus status;
  final FriendProfile? target;
}

class FriendsOverview {
  const FriendsOverview({
    required this.friends,
    required this.incoming,
    required this.outgoing,
  });

  final List<FriendProfile> friends;
  final List<FriendProfile> incoming;
  final List<FriendProfile> outgoing;
}

/// Friend rules on top of a [FriendStore]: find by code, request, accept.
class FriendService {
  FriendService(this._store, {Random? random}) : _random = random ?? Random();

  final FriendStore _store;
  final Random _random;

  Future<FriendProfile> myProfile(String uid, String name) =>
      _store.ensureProfile(uid, name, _random);

  Future<FriendsOverview> load(String uid) async {
    final results = await Future.wait([
      _store.friends(uid),
      _store.incoming(uid),
      _store.outgoing(uid),
    ]);
    return FriendsOverview(
      friends: results[0],
      incoming: results[1],
      outgoing: results[2],
    );
  }

  Future<AddFriendResult> sendRequest(FriendProfile me, String rawCode) async {
    final code = FriendCode.normalize(rawCode);
    if (code == null) return const AddFriendResult(AddFriendStatus.invalidCode);
    if (code == me.code) return const AddFriendResult(AddFriendStatus.self);

    final target = await _store.findByCode(code);
    if (target == null) return const AddFriendResult(AddFriendStatus.notFound);

    final overview = await load(me.uid);
    bool has(List<FriendProfile> l) => l.any((p) => p.uid == target.uid);
    if (has(overview.friends)) {
      return AddFriendResult(AddFriendStatus.alreadyFriends, target);
    }
    if (has(overview.outgoing)) {
      return AddFriendResult(AddFriendStatus.alreadyRequested, target);
    }
    if (has(overview.incoming)) {
      return AddFriendResult(AddFriendStatus.theyRequestedYou, target);
    }
    await _store.sendRequest(me, target);
    return AddFriendResult(AddFriendStatus.sent, target);
  }

  Future<void> accept(FriendProfile me, FriendProfile from) =>
      _store.accept(me, from);
  Future<void> decline(String myUid, String fromUid) =>
      _store.decline(myUid, fromUid);
  Future<void> cancel(String myUid, String toUid) =>
      _store.cancel(myUid, toUid);
  Future<void> remove(String myUid, String friendUid) =>
      _store.remove(myUid, friendUid);
}
