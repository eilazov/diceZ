import 'game_result.dart';
import 'score_card.dart';

/// Aggregate figures derived from stored [GameResult]s.
class Statistics {
  Statistics._({
    required this.gamesPlayed,
    required this.averageScore,
    required this.bestByCategory,
  });

  final int gamesPlayed;

  /// Mean of every player's final total across every game; 0 when none.
  final double averageScore;

  /// Highest value ever committed to each category; 0 when never scored.
  final Map<ScoreCategory, int> bestByCategory;

  factory Statistics.from(List<GameResult> history) {
    final totals = <int>[
      for (final game in history)
        for (final player in game.players) player.total,
    ];

    final best = {for (final c in ScoreCategory.values) c: 0};
    for (final game in history) {
      for (final player in game.players) {
        player.categoryScores.forEach((category, score) {
          if (score > best[category]!) best[category] = score;
        });
      }
    }

    return Statistics._(
      gamesPlayed: history.length,
      averageScore: totals.isEmpty
          ? 0.0
          : totals.reduce((a, b) => a + b) / totals.length,
      bestByCategory: best,
    );
  }
}
