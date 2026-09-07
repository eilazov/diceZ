import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dice_zee/models/game_result.dart';
import 'package:dice_zee/models/score_card.dart';
import 'package:dice_zee/services/game_storage.dart';

GameResult result({required int playerCount, required DateTime at}) => GameResult(
      playedAt: at,
      playerCount: playerCount,
      players: [
        for (var p = 0; p < playerCount; p++)
          PlayerScore(categoryScores: {
            for (final c in ScoreCategory.values) c: p + 1,
          }),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  const storage = GameStorage();

  test('loadHistory is empty when nothing has been saved', () async {
    expect(await storage.loadHistory(), isEmpty);
  });

  test('a saved result can be read back', () async {
    await storage.saveResult(
      result(playerCount: 3, at: DateTime.utc(2026, 9, 7, 12)),
    );

    final history = await storage.loadHistory();
    expect(history, hasLength(1));
    expect(history.single.playerCount, 3);
    expect(history.single.players[2].total, 45); // 15 categories * 3
  });

  test('history is ordered newest first', () async {
    await storage.saveResult(
      result(playerCount: 2, at: DateTime.utc(2026, 1, 1)),
    );
    await storage.saveResult(
      result(playerCount: 4, at: DateTime.utc(2026, 2, 2)),
    );

    final counts =
        (await storage.loadHistory()).map((r) => r.playerCount).toList();
    expect(counts, [4, 2]);
  });

  test('unparseable legacy entries are skipped, not thrown', () async {
    SharedPreferences.setMockInitialValues({
      'dice_zee.history': jsonEncode([
        {'playedAt': '2026-01-01T00:00:00.000Z', 'totalScore': 210}, // old shape
        result(playerCount: 2, at: DateTime.utc(2026, 3, 3)).toJson(),
      ]),
    });

    final history = await storage.loadHistory();
    expect(history, hasLength(1));
    expect(history.single.playerCount, 2);
  });
}
