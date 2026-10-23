import 'game_mode.dart';
import 'score_card.dart';

/// One player's finished card: every category's score, plus which local
/// profile (if any) played this seat.
class PlayerScore {
  const PlayerScore({
    required this.categoryScores,
    this.upperBonus = 0,
    this.profileId,
    this.name,
  });

  final Map<ScoreCategory, int> categoryScores;

  /// Upper-section bonus earned (standard mode); 0 otherwise.
  final int upperBonus;

  /// The [PlayerProfile.id] that played this seat, or null for a guest.
  final String? profileId;

  /// A snapshot of the display name at the time the match was played, so
  /// history stays readable after a rename or delete. Null for a guest.
  final String? name;

  int get total => categoryScores.values.fold(0, (a, b) => a + b) + upperBonus;

  Map<String, dynamic> toJson() => {
        for (final entry in categoryScores.entries) entry.key.name: entry.value,
        'upperBonus': upperBonus,
        'profileId': profileId,
        'name': name,
      };

  factory PlayerScore.fromJson(Map<String, dynamic> json) => PlayerScore(
        categoryScores: {
          for (final category in ScoreCategory.values)
            category: (json[category.name] as num?)?.toInt() ?? 0,
        },
        upperBonus: (json['upperBonus'] as num?)?.toInt() ?? 0,
        profileId: json['profileId'] as String?,
        name: json['name'] as String?,
      );
}

/// A finished game's outcome, as stored in local history.
class GameResult {
  const GameResult({
    required this.playedAt,
    required this.playerCount,
    required this.players,
    this.mode = GameMode.extended,
  });

  final DateTime playedAt;
  final int playerCount;
  final List<PlayerScore> players;

  /// The rule set played; matches saved before modes existed are extended.
  final GameMode mode;

  int get winningScore =>
      players.map((p) => p.total).fold(0, (a, b) => a > b ? a : b);

  Map<String, dynamic> toJson() => {
        'playedAt': playedAt.toIso8601String(),
        'mode': mode.name,
        'playerCount': playerCount,
        'players': players.map((p) => p.toJson()).toList(),
      };

  factory GameResult.fromJson(Map<String, dynamic> json) => GameResult(
        playedAt: DateTime.parse(json['playedAt'] as String),
        mode: GameMode.fromName(json['mode'] as String?),
        playerCount: (json['playerCount'] as num).toInt(),
        players: (json['players'] as List<dynamic>)
            .map((e) => PlayerScore.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
