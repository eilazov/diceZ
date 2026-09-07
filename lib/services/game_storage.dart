import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_result.dart';

/// Local persistence for finished games, backed by [SharedPreferences].
///
/// The whole history lives under one key as a JSON array, newest first.
class GameStorage {
  const GameStorage();

  static const String _historyKey = 'dice_zee.history';

  /// Every stored [GameResult], most recent first.
  Future<List<GameResult>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => GameResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Prepend [result] to the history and persist.
  Future<void> saveResult(GameResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await loadHistory()..insert(0, result);
    final encoded = jsonEncode(history.map((r) => r.toJson()).toList());
    await prefs.setString(_historyKey, encoded);
  }
}
