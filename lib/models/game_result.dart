import 'score_card.dart';

/// One player's finished card: every category's score.
class PlayerScore {
  const PlayerScore({required this.categoryScores});

  final Map<ScoreCategory, int> categoryScores;

  int get total => categoryScores.values.fold(0, (a, b) => a + b);

  Map<String, dynamic> toJson() => {
        for (final entry in categoryScores.entries) entry.key.name: entry.value,
      };

  factory PlayerScore.fromJson(Map<String, dynamic> json) => PlayerScore(
        categoryScores: {
          for (final category in ScoreCategory.values)
            category: (json[category.name] as num?)?.toInt() ?? 0,
        },
      );
}

/// A finished game's outcome, as stored in local history.
class GameResult {
  const GameResult({
    required this.playedAt,
    required this.playerCount,
    required this.players,
  });

  final DateTime playedAt;
  final int playerCount;
  final List<PlayerScore> players;

  int get winningScore =>
      players.map((p) => p.total).fold(0, (a, b) => a > b ? a : b);

  Map<String, dynamic> toJson() => {
        'playedAt': playedAt.toIso8601String(),
        'playerCount': playerCount,
        'players': players.map((p) => p.toJson()).toList(),
      };

  factory GameResult.fromJson(Map<String, dynamic> json) => GameResult(
        playedAt: DateTime.parse(json['playedAt'] as String),
        playerCount: (json['playerCount'] as num).toInt(),
        players: (json['players'] as List<dynamic>)
            .map((e) => PlayerScore.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
