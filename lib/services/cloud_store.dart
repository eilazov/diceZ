import '../models/game_result.dart';

/// One signed-in account's remote data. Plain interface so sync logic can be
/// tested without Firebase.
abstract class CloudStore {
  Future<List<GameResult>> loadMatches();

  /// Idempotent per match: re-saving the same [GameResult.playedAt] replaces.
  Future<void> saveMatches(List<GameResult> matches);

  /// Removes every synced match of the account (account deletion).
  Future<void> deleteAllMatches();
}
