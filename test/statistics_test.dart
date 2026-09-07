import 'package:flutter_test/flutter_test.dart';
import 'package:dice_zee/models/game_result.dart';
import 'package:dice_zee/models/score_card.dart';
import 'package:dice_zee/models/statistics.dart';

PlayerScore player(Map<ScoreCategory, int> overrides) => PlayerScore(
      categoryScores: {
        for (final c in ScoreCategory.values) c: overrides[c] ?? 0,
      },
    );

GameResult game(List<PlayerScore> players) => GameResult(
      playedAt: DateTime.utc(2026, 1, 1),
      playerCount: players.length,
      players: players,
    );

void main() {
  group('empty history', () {
    final stats = Statistics.from(const []);

    test('reports nothing played', () {
      expect(stats.gamesPlayed, 0);
      expect(stats.averageScore, 0.0);
    });

    test('best-by-category is zero for every category', () {
      for (final c in ScoreCategory.values) {
        expect(stats.bestByCategory[c], 0);
      }
    });
  });

  group('with games', () {
    final history = [
      game([
        player({ScoreCategory.sixes: 18, ScoreCategory.yahtzee: 100}), // 118
        player({ScoreCategory.chance: 20}), //  20
      ]),
      game([
        player({ScoreCategory.fullHouse: 25, ScoreCategory.sixes: 12}), //  37
        player({ScoreCategory.yahtzee: 100, ScoreCategory.chance: 25}), // 125
      ]),
    ];

    final stats = Statistics.from(history);

    test('counts games', () {
      expect(stats.gamesPlayed, 2);
    });

    test('averages every player total across every game', () {
      // (118 + 20 + 37 + 125) / 4 = 75.0
      expect(stats.averageScore, 75.0);
    });

    test('best-by-category takes the max seen anywhere', () {
      expect(stats.bestByCategory[ScoreCategory.sixes], 18);
      expect(stats.bestByCategory[ScoreCategory.yahtzee], 100);
      expect(stats.bestByCategory[ScoreCategory.chance], 25);
      expect(stats.bestByCategory[ScoreCategory.fullHouse], 25);
      expect(stats.bestByCategory[ScoreCategory.ones], 0);
    });
  });
}
