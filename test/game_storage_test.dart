import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dice_zee/models/game_result.dart';
import 'package:dice_zee/services/game_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  final storage = GameStorage();

  test('loadHistory is empty when nothing has been saved', () async {
    expect(await storage.loadHistory(), isEmpty);
  });

  test('a saved result can be read back', () async {
    final result = GameResult(
      playedAt: DateTime.utc(2026, 9, 7, 12),
      totalScore: 180,
    );

    await storage.saveResult(result);
    final history = await storage.loadHistory();

    expect(history, hasLength(1));
    expect(history.single.totalScore, 180);
    expect(history.single.playedAt, result.playedAt);
  });

  test('history is ordered newest first', () async {
    await storage.saveResult(
      GameResult(playedAt: DateTime.utc(2026, 1, 1), totalScore: 100),
    );
    await storage.saveResult(
      GameResult(playedAt: DateTime.utc(2026, 2, 2), totalScore: 200),
    );

    final scores = (await storage.loadHistory()).map((r) => r.totalScore).toList();

    expect(scores, [200, 100]);
  });
}
