import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/friend_code.dart';
import '../models/friend_profile.dart';
import 'friend_store.dart';

/// Firestore layout:
///   friendCodes/{code}                 { uid, name }
///   users/{uid}                        { friendCode, displayName } (merged)
///   users/{uid}/friends/{otherUid}     FriendProfile json
///   users/{uid}/friendRequests/{from}  FriendProfile json of the sender
///   users/{uid}/sentRequests/{to}      FriendProfile json of the recipient
class FirestoreFriendStore implements FriendStore {
  FirestoreFriendStore({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _sub(String uid, String name) =>
      _user(uid).collection(name);

  @override
  Future<FriendProfile> ensureProfile(
    String uid,
    String name,
    Random random,
  ) async {
    final existing = (await _user(uid).get()).data()?['friendCode'] as String?;
    if (existing != null) {
      return FriendProfile(uid: uid, name: name, code: existing);
    }
    while (true) {
      final code = FriendCode.generate(random);
      final claimed = await _db.runTransaction((tx) async {
        final ref = _db.collection('friendCodes').doc(code);
        if ((await tx.get(ref)).exists) return false;
        tx.set(ref, {'uid': uid, 'name': name});
        tx.set(_user(uid), {
          'friendCode': code,
          'displayName': name,
        }, SetOptions(merge: true));
        return true;
      });
      if (claimed) return FriendProfile(uid: uid, name: name, code: code);
    }
  }

  @override
  Future<FriendProfile?> findByCode(String code) async {
    final data = (await _db.collection('friendCodes').doc(code).get()).data();
    if (data == null) return null;
    return FriendProfile(
      uid: data['uid'] as String,
      name: data['name'] as String,
      code: code,
    );
  }

  Future<List<FriendProfile>> _list(String uid, String name) async {
    final snapshot = await _sub(uid, name).get();
    return [
      for (final doc in snapshot.docs)
        if (_tryProfile(doc.data()) case final FriendProfile p) p,
    ];
  }

  static FriendProfile? _tryProfile(Map<String, dynamic> data) {
    try {
      return FriendProfile.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<FriendProfile>> friends(String uid) => _list(uid, 'friends');

  @override
  Future<List<FriendProfile>> incoming(String uid) =>
      _list(uid, 'friendRequests');

  @override
  Future<List<FriendProfile>> outgoing(String uid) =>
      _list(uid, 'sentRequests');

  @override
  Future<void> sendRequest(FriendProfile from, FriendProfile to) async {
    // Sender's own record first: the rules for the recipient's inbox check it.
    await _sub(from.uid, 'sentRequests').doc(to.uid).set(to.toJson());
    await _sub(to.uid, 'friendRequests').doc(from.uid).set(from.toJson());
  }

  @override
  Future<void> accept(FriendProfile me, FriendProfile from) async {
    // Their friends list first: the rules need their sentRequests entry,
    // which is removed in the batch below.
    await _sub(from.uid, 'friends').doc(me.uid).set(me.toJson());
    final batch = _db.batch();
    batch.set(_sub(me.uid, 'friends').doc(from.uid), from.toJson());
    batch.delete(_sub(me.uid, 'friendRequests').doc(from.uid));
    batch.delete(_sub(from.uid, 'sentRequests').doc(me.uid));
    await batch.commit();
  }

  @override
  Future<void> decline(String myUid, String fromUid) async {
    await _sub(myUid, 'friendRequests').doc(fromUid).delete();
    await _sub(fromUid, 'sentRequests').doc(myUid).delete();
  }

  @override
  Future<void> cancel(String myUid, String toUid) async {
    await _sub(myUid, 'sentRequests').doc(toUid).delete();
    await _sub(toUid, 'friendRequests').doc(myUid).delete();
  }

  @override
  Future<void> remove(String myUid, String friendUid) async {
    await _sub(myUid, 'friends').doc(friendUid).delete();
    await _sub(friendUid, 'friends').doc(myUid).delete();
  }
}
