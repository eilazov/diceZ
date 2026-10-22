import '../models/game_result.dart';
import '../models/player_profile.dart';

/// One signed-in account's remote data. Plain interface so sync logic can be
/// tested without Firebase.
abstract class CloudStore {
  /// The saved player list, or null if none has been saved yet.
  Future<List<PlayerProfile>?> loadPlayers();
  Future<void> savePlayers(List<PlayerProfile> players);

  Future<List<GameResult>> loadMatches();

  /// Idempotent per match: re-saving the same [GameResult.playedAt] replaces.
  Future<void> saveMatches(List<GameResult> matches);
}
