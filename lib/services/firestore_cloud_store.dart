import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/game_result.dart';
import '../models/player_profile.dart';
import 'cloud_store.dart';

/// Firestore layout:
///   users/{uid}                 { players: [PlayerProfile json] }
///   users/{uid}/matches/{id}    GameResult json, id = playedAt in microseconds
class FirestoreCloudStore implements CloudStore {
  FirestoreCloudStore(this.uid, {FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _user =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> get _matches =>
      _user.collection('matches');

  @override
  Future<List<PlayerProfile>?> loadPlayers() async {
    final data = (await _user.get()).data();
    final raw = data?['players'] as List<dynamic>?;
    if (raw == null) return null;
    return [
      for (final entry in raw)
        if (_tryProfile(entry) case final PlayerProfile profile) profile,
    ];
  }

  static PlayerProfile? _tryProfile(dynamic entry) {
    try {
      return PlayerProfile.fromJson(Map<String, dynamic>.from(entry as Map));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> savePlayers(List<PlayerProfile> players) => _user.set({
    'players': players.map((p) => p.toJson()).toList(),
  }, SetOptions(merge: true));

  @override
  Future<List<GameResult>> loadMatches() async {
    final snapshot = await _matches.get();
    return [
      for (final doc in snapshot.docs)
        if (_tryResult(doc.data()) case final GameResult result) result,
    ];
  }

  static GameResult? _tryResult(Map<String, dynamic> data) {
    try {
      return GameResult.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveMatches(List<GameResult> matches) async {
    final batch = _db.batch();
    for (final match in matches) {
      batch.set(_matches.doc(matchId(match)), match.toJson());
    }
    await batch.commit();
  }

  static String matchId(GameResult match) =>
      match.playedAt.toUtc().microsecondsSinceEpoch.toString();
}
