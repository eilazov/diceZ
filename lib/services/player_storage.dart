import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/player_profile.dart';

/// Local persistence for player profiles, backed by [SharedPreferences].
///
/// All profiles live under one key as a JSON array, in add order.
class PlayerStorage {
  const PlayerStorage();

  static const String _profilesKey = 'dice_zee.players';

  /// Every stored [PlayerProfile], in the order they were added.
  Future<List<PlayerProfile>> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profilesKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return [
      for (final entry in decoded)
        if (_tryParse(entry) case final PlayerProfile profile) profile,
    ];
  }

  /// Parse one stored entry, or null if it is not a current-shape
  /// [PlayerProfile].
  static PlayerProfile? _tryParse(dynamic entry) {
    try {
      return PlayerProfile.fromJson(entry as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveProfiles(List<PlayerProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(profiles.map((p) => p.toJson()).toList());
    await prefs.setString(_profilesKey, encoded);
  }

  /// Append a new profile named [name] with a freshly generated id.
  Future<void> addProfile(String name) async {
    final profiles = await loadProfiles();
    profiles.add(PlayerProfile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
    ));
    await _saveProfiles(profiles);
  }

  /// Rename the profile with id [id] to [name]. No-op if not found.
  Future<void> renameProfile(String id, String name) async {
    final profiles = await loadProfiles();
    final index = profiles.indexWhere((p) => p.id == id);
    if (index == -1) return;
    profiles[index] = PlayerProfile(id: id, name: name);
    await _saveProfiles(profiles);
  }

  /// Remove the profile with id [id]. No-op if not found.
  Future<void> deleteProfile(String id) async {
    final profiles = await loadProfiles();
    profiles.removeWhere((p) => p.id == id);
    await _saveProfiles(profiles);
  }
}
