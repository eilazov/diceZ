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

  /// Overwrite the stored list (used by cloud sync).
  Future<void> replaceProfiles(List<PlayerProfile> profiles) =>
      _saveProfiles(profiles);

  Future<void> _saveProfiles(List<PlayerProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(profiles.map((p) => p.toJson()).toList());
    await prefs.setString(_profilesKey, encoded);
  }

  /// Append a new profile named [name] with a freshly generated id.
  Future<void> addProfile(String name) async {
    final profiles = await loadProfiles();
    profiles.add(
      PlayerProfile(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
      ),
    );
    await _saveProfiles(profiles);
  }

  /// Rename the profile with id [id] to [name]. No-op if not found.
  Future<void> renameProfile(String id, String name) async {
    final profiles = await loadProfiles();
    final index = profiles.indexWhere((p) => p.id == id);
    if (index == -1) return;
    profiles[index] = PlayerProfile(
      id: id,
      name: name,
      linkedToAccount: profiles[index].linkedToAccount,
    );
    await _saveProfiles(profiles);
  }

  /// Remove the profile with id [id]. No-op if not found or if it is the
  /// account profile (see [removeAccountProfile]).
  Future<void> deleteProfile(String id) async {
    final profiles = await loadProfiles();
    profiles.removeWhere((p) => p.id == id && !p.linkedToAccount);
    await _saveProfiles(profiles);
  }

  /// Make sure the signed-in account [uid] has a profile, listed first. The
  /// id is derived from [uid], so the same account keeps its history across
  /// sign-outs. An existing profile (and any rename of it) is left alone.
  Future<void> ensureAccountProfile(String uid, String name) async {
    final profiles = await loadProfiles();
    final id = 'account_$uid';
    if (profiles.any((p) => p.id == id)) return;
    profiles.removeWhere((p) => p.linkedToAccount);
    profiles.insert(
      0,
      PlayerProfile(id: id, name: name, linkedToAccount: true),
    );
    await _saveProfiles(profiles);
  }

  /// Drop the account profile on sign-out. Past games keep its id and name.
  Future<void> removeAccountProfile() async {
    final profiles = await loadProfiles();
    profiles.removeWhere((p) => p.linkedToAccount);
    await _saveProfiles(profiles);
  }
}
