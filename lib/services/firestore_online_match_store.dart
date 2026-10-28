import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/online_match.dart';
import 'online_match_store.dart';

/// Firestore layout: liveMatches/{id}, one document per match (see
/// [OnlineMatch.toJson]); `players` holds both uids for the membership query.
class FirestoreOnlineMatchStore implements OnlineMatchStore {
  FirestoreOnlineMatchStore({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _matches =>
      _db.collection('liveMatches');

  static OnlineMatch? _parse(String id, Map<String, dynamic>? data) {
    if (data == null) return null;
    try {
      return OnlineMatch.fromJson(id, data);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> create(OnlineMatch match) async =>
      (await _matches.add(match.toJson())).id;

  @override
  Future<OnlineMatch?> get(String id) async {
    final doc = await _matches.doc(id).get();
    return _parse(doc.id, doc.data());
  }

  @override
  Stream<OnlineMatch?> watch(String id) =>
      _matches.doc(id).snapshots().map((d) => _parse(d.id, d.data()));

  @override
  Stream<List<OnlineMatch>> watchFor(String uid) => _matches
      .where('players', arrayContains: uid)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            if (_parse(d.id, d.data()) case final OnlineMatch m) m,
        ],
      );

  @override
  Future<void> update(OnlineMatch match) =>
      _matches.doc(match.id).set(match.toJson());

  @override
  Future<void> delete(String id) => _matches.doc(id).delete();
}
