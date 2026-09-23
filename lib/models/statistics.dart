import 'dart:math';

import 'game_result.dart';
import 'score_card.dart';

/// Aggregate figures derived from stored [GameResult]s, optionally scoped to
/// one [PlayerProfile] via its id.
class Statistics {
  Statistics._({
    required this.gamesPlayed,
    required this.averageScore,
    required this.bestByCategory,
    required this.wins,
  });

  /// Games played: total games when unscoped, or games this profile
  /// appeared in when scoped.
  final int gamesPlayed;

  /// Mean of every scoped total across every scoped game; 0 when none.
  final double averageScore;

  /// Highest value ever committed to each category within scope; 0 when
  /// never scored in scope.
  final Map<ScoreCategory, int> bestByCategory;

  /// Games where this profile's seat held the strictly-highest total. Ties
  /// credit nobody. Always 0 when unscoped (profileId == null).
  final int wins;

  /// [profileId] == null aggregates every game ("Everyone"); otherwise only
  /// the slots played by that profile.
  factory Statistics.from(List<GameResult> history, {String? profileId}) {
    final slots = [
      for (final game in history)
        for (final player in game.players)
          if (profileId == null || player.profileId == profileId) player,
    ];

    final totals = [for (final p in slots) p.total];

    final best = {for (final c in ScoreCategory.values) c: 0};
    for (final p in slots) {
      p.categoryScores.forEach((category, score) {
        if (score > best[category]!) best[category] = score;
      });
    }

    var wins = 0;
    if (profileId != null) {
      for (final game in history) {
        final gameTotals = [for (final p in game.players) p.total];
        final bestTotal = gameTotals.reduce(max);
        final leaders = [
          for (var i = 0; i < gameTotals.length; i++)
            if (gameTotals[i] == bestTotal) i,
        ];
        if (leaders.length == 1 &&
            game.players[leaders.single].profileId == profileId) {
          wins++;
        }
      }
    }

    return Statistics._(
      gamesPlayed: profileId == null ? history.length : slots.length,
      averageScore: totals.isEmpty
          ? 0.0
          : totals.reduce((a, b) => a + b) / totals.length,
      bestByCategory: best,
      wins: wins,
    );
  }
}
