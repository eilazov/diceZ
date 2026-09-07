import 'package:flutter_test/flutter_test.dart';
import 'package:dice_zee/models/game_result.dart';
import 'package:dice_zee/models/score_card.dart';

void main() {
  group('PlayerScore', () {
    test('total sums every category score', () {
      final score = PlayerScore(categoryScores: {
        for (final c in ScoreCategory.values) c: 0,
        ScoreCategory.sixes: 18,
        ScoreCategory.yahtzee: 100,
      });

      expect(score.total, 118);
    });

    test('round-trips through JSON', () {
      final score = PlayerScore(categoryScores: {
        for (final c in ScoreCategory.values) c: c.index,
      });

      final restored = PlayerScore.fromJson(score.toJson());

      expect(restored.categoryScores, score.categoryScores);
      expect(restored.total, score.total);
    });
  });

  group('GameResult', () {
    GameResult sample() => GameResult(
          playedAt: DateTime.utc(2026, 9, 7, 15),
          playerCount: 2,
          players: [
            PlayerScore(categoryScores: {
              for (final c in ScoreCategory.values) c: 1,
            }),
            PlayerScore(categoryScores: {
              for (final c in ScoreCategory.values) c: 2,
            }),
          ],
        );

    test('winningScore is the highest player total', () {
      expect(sample().winningScore, 30); // 15 categories * 2
    });

    test('round-trips through JSON', () {
      final result = sample();
      final restored = GameResult.fromJson(result.toJson());

      expect(restored.playedAt, result.playedAt);
      expect(restored.playerCount, 2);
      expect(restored.players, hasLength(2));
      expect(restored.players[0].total, 15);
      expect(restored.players[1].total, 30);
    });
  });
}
