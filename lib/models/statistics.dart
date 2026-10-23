import 'dart:math';

import 'game_mode.dart';
import 'game_result.dart';
import 'score_card.dart';
import 'statistics_extras.dart';

/// Aggregate figures derived from stored [GameResult]s of one [GameMode],
/// optionally scoped to one [PlayerProfile] via its id.
class Statistics {
  Statistics._({
    required this.gamesPlayed,
    required this.averageScore,
    required this.bestScore,
    required this.worstScore,
    required this.bestByCategory,
    required this.wins,
    required this.winRate,
    required this.currentWinStreak,
    required this.longestWinStreak,
    required this.biggestMargin,
    required this.yahtzeeCount,
    required this.bonusCount,
    required this.averageByCategory,
    required this.zeroCountByCategory,
    required this.recentAverage,
    required this.headToHead,
    required this.byPlayerCount,
  });

  /// Games played: total games when unscoped, or games this profile
  /// appeared in when scoped.
  final int gamesPlayed;

  /// Mean of every scoped total across every scoped game; 0 when none.
  final double averageScore;

  /// Highest single game total within scope; 0 when none.
  final int bestScore;

  /// Lowest single game total within scope; 0 when none.
  final int worstScore;

  /// Highest value ever committed to each category within scope; 0 when
  /// never scored in scope.
  final Map<ScoreCategory, int> bestByCategory;

  /// Games where this profile's seat held the strictly-highest total. Ties
  /// credit nobody. Always 0 when unscoped (profileId == null).
  final int wins;

  /// [wins] / [gamesPlayed]; 0 when none (and when unscoped).
  final double winRate;

  /// Consecutive wins ending at the latest game this profile played, and the
  /// longest run ever. A tie or loss breaks a streak. 0 when unscoped.
  final int currentWinStreak;
  final int longestWinStreak;

  /// Largest lead over second place in a game: this profile's wins when
  /// scoped, any game when unscoped. 0 when none.
  final int biggestMargin;

  /// Cards (within scope) that scored the Dice Zee category.
  final int yahtzeeCount;

  /// Cards (within scope) that earned the upper-section bonus.
  final int bonusCount;

  /// Mean committed score per category within scope; 0 when none.
  final Map<ScoreCategory, double> averageByCategory;

  /// Cards (within scope) that scratched each category for 0.
  final Map<ScoreCategory, int> zeroCountByCategory;

  /// Mean total of the most recent [recentWindow] cards in scope; 0 when none.
  final double recentAverage;
  static const int recentWindow = 10;

  /// Record against each named opponent, most games first. Empty when
  /// unscoped.
  final List<HeadToHead> headToHead;

  /// Games, average and wins keyed by player count; only counts that occur.
  final Map<int, PlayerCountStats> byPlayerCount;

  /// [profileId] == null aggregates every game ("Everyone"); otherwise only
  /// the slots played by that profile.
  factory Statistics.from(
    List<GameResult> history, {
    String? profileId,
    GameMode mode = GameMode.extended,
  }) {
    // Newest first, whatever order storage returned.
    final games = [
      for (final g in history)
        if (g.mode == mode) g,
    ]..sort((a, b) => b.playedAt.compareTo(a.playedAt));

    final slots = <PlayerScore>[];
    final slotGames = <GameResult>[];
    for (final game in games) {
      for (final player in game.players) {
        if (profileId == null || player.profileId == profileId) {
          slots.add(player);
          slotGames.add(game);
        }
      }
    }
    final totals = [for (final p in slots) p.total];

    final categories = mode.categories;
    final best = {for (final c in categories) c: 0};
    final sums = {for (final c in categories) c: 0};
    final zeros = {for (final c in categories) c: 0};
    var yahtzees = 0;
    var bonuses = 0;
    for (final p in slots) {
      for (final category in categories) {
        final score = p.categoryScores[category] ?? 0;
        if (score > best[category]!) best[category] = score;
        sums[category] = sums[category]! + score;
        if (score == 0) zeros[category] = zeros[category]! + 1;
      }
      if ((p.categoryScores[ScoreCategory.yahtzee] ?? 0) > 0) yahtzees++;
      if (p.upperBonus > 0) bonuses++;
    }

    // Per-game outcome for the scoped profile: index of the strict leader.
    int? leader(GameResult game) {
      final t = [for (final p in game.players) p.total];
      if (t.isEmpty) return null;
      final top = t.reduce(max);
      final leaders = [
        for (var i = 0; i < t.length; i++)
          if (t[i] == top) i,
      ];
      return leaders.length == 1 ? leaders.single : null;
    }

    int margin(GameResult game) {
      final t = [for (final p in game.players) p.total]..sort();
      return t.length < 2 ? 0 : t[t.length - 1] - t[t.length - 2];
    }

    var wins = 0;
    var biggestMargin = 0;
    var current = 0;
    var longest = 0;
    var run = 0;
    var stillCurrent = true;
    final opponents = <String, ({String name, int w, int l, int t})>{};
    final countGames = <int, int>{};
    final countTotals = <int, int>{};
    final countSlots = <int, int>{};
    final countWins = <int, int>{};

    if (profileId == null) {
      for (final game in games) {
        if (margin(game) > biggestMargin) biggestMargin = margin(game);
      }
    } else {
      // Oldest first so streaks accumulate chronologically.
      final played = games.reversed
          .where((g) => g.players.any((p) => p.profileId == profileId))
          .toList();
      final outcomes = <bool>[];
      for (final game in played) {
        final winner = leader(game);
        final won =
            winner != null && game.players[winner].profileId == profileId;
        outcomes.add(won);
        if (won) {
          wins++;
          run++;
          if (run > longest) longest = run;
          if (margin(game) > biggestMargin) biggestMargin = margin(game);
        } else {
          run = 0;
        }
      }
      for (final won in outcomes.reversed) {
        if (!won) stillCurrent = false;
        if (stillCurrent) current++;
      }

      for (final game in played) {
        final mine = game.players.firstWhere((p) => p.profileId == profileId);
        for (final other in game.players) {
          final id = other.profileId;
          if (id == null || id == profileId) continue;
          final prev = opponents[id] ?? (name: '', w: 0, l: 0, t: 0);
          final name = other.name ?? prev.name;
          opponents[id] = mine.total > other.total
              ? (name: name, w: prev.w + 1, l: prev.l, t: prev.t)
              : mine.total < other.total
              ? (name: name, w: prev.w, l: prev.l + 1, t: prev.t)
              : (name: name, w: prev.w, l: prev.l, t: prev.t + 1);
        }
      }
    }

    for (var i = 0; i < slots.length; i++) {
      final n = slotGames[i].playerCount;
      countSlots[n] = (countSlots[n] ?? 0) + 1;
      countTotals[n] = (countTotals[n] ?? 0) + slots[i].total;
    }
    for (final game in games) {
      if (profileId != null &&
          !game.players.any((p) => p.profileId == profileId)) {
        continue;
      }
      final n = game.playerCount;
      countGames[n] = (countGames[n] ?? 0) + 1;
      final winner = leader(game);
      if (profileId != null &&
          winner != null &&
          game.players[winner].profileId == profileId) {
        countWins[n] = (countWins[n] ?? 0) + 1;
      }
    }

    // Latest name wins: `games` is newest first, so iterate that way.
    final latestNames = <String, String>{};
    if (profileId != null) {
      for (final game in games) {
        for (final p in game.players) {
          final id = p.profileId;
          if (id != null && p.name != null) {
            latestNames.putIfAbsent(id, () => p.name!);
          }
        }
      }
    }

    final recent = totals.take(recentWindow).toList();
    final headToHead = [
      for (final e in opponents.entries)
        HeadToHead(
          opponentId: e.key,
          name: latestNames[e.key] ?? e.value.name,
          wins: e.value.w,
          losses: e.value.l,
          ties: e.value.t,
        ),
    ]..sort((a, b) => b.games.compareTo(a.games));

    final gamesPlayed = profileId == null ? games.length : slots.length;

    return Statistics._(
      gamesPlayed: gamesPlayed,
      averageScore: totals.isEmpty
          ? 0.0
          : totals.reduce((a, b) => a + b) / totals.length,
      bestScore: totals.isEmpty ? 0 : totals.reduce(max),
      worstScore: totals.isEmpty ? 0 : totals.reduce(min),
      bestByCategory: best,
      wins: wins,
      winRate: profileId == null || gamesPlayed == 0 ? 0.0 : wins / gamesPlayed,
      currentWinStreak: current,
      longestWinStreak: longest,
      biggestMargin: biggestMargin,
      yahtzeeCount: yahtzees,
      bonusCount: bonuses,
      averageByCategory: {
        for (final c in categories)
          c: slots.isEmpty ? 0.0 : sums[c]! / slots.length,
      },
      zeroCountByCategory: zeros,
      recentAverage: recent.isEmpty
          ? 0.0
          : recent.reduce((a, b) => a + b) / recent.length,
      headToHead: headToHead,
      byPlayerCount: {
        for (final n in (countSlots.keys.toList()..sort()))
          n: PlayerCountStats(
            games: countGames[n] ?? 0,
            averageScore: countTotals[n]! / countSlots[n]!,
            wins: countWins[n] ?? 0,
          ),
      },
    );
  }
}
