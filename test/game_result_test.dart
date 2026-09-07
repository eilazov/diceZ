import 'package:flutter_test/flutter_test.dart';
import 'package:dice_zee/models/game_result.dart';

void main() {
  group('GameResult', () {
    test('round-trips through JSON', () {
      final result = GameResult(
        playedAt: DateTime.utc(2026, 9, 7, 14, 30),
        totalScore: 214,
      );

      final restored = GameResult.fromJson(result.toJson());

      expect(restored.playedAt, result.playedAt);
      expect(restored.totalScore, result.totalScore);
    });

    test('toJson uses an ISO-8601 string for the date', () {
      final result = GameResult(
        playedAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
        totalScore: 100,
      );

      expect(result.toJson()['playedAt'], '2026-01-02T03:04:05.000Z');
      expect(result.toJson()['totalScore'], 100);
    });
  });
}
