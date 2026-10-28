import '../models/online_match.dart';

/// Remote storage for [OnlineMatch]es. Plain interface so the service can be
/// tested without Firebase.
abstract class OnlineMatchStore {
  /// Stores a new match and returns its generated id.
  Future<String> create(OnlineMatch match);

  Future<OnlineMatch?> get(String id);

  /// Emits the match whenever it changes; null once it is deleted.
  Stream<OnlineMatch?> watch(String id);

  /// Every match [uid] is a player in, re-emitted on any change.
  Stream<List<OnlineMatch>> watchFor(String uid);

  Future<void> update(OnlineMatch match);
  Future<void> delete(String id);
}
