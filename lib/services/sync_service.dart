import 'dart:async';

import '../models/game_result.dart';
import '../models/player_profile.dart';
import 'auth_service.dart';
import 'cloud_store.dart';
import 'game_storage.dart';
import 'player_storage.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// Keeps local players and match history mirrored to the signed-in account's
/// [CloudStore]. Local storage stays the source of truth, so everything works
/// offline and as a guest; sync failures are swallowed and retried on the
/// next pull.
///
/// - [pull] (sign-in / app start): merge cloud into local, upload what the
///   cloud lacks. The first pull for an account unions both player lists;
///   later pulls treat the cloud list as authoritative so deletions made on
///   another device propagate.
/// - [pushPlayers] / [pushMatch]: write-through after a local change.
///
/// The account's own profile ([PlayerProfile.linkedToAccount]) is derived
/// from the uid on each device and is never uploaded.
class SyncService {
  SyncService({
    this.players = const PlayerStorage(),
    this.games = const GameStorage(),
  });

  /// The instance the app wires up in `main()`.
  static final SyncService instance = SyncService();

  static const String _syncedUidKey = 'dice_zee.syncedUid';

  final PlayerStorage players;
  final GameStorage games;

  CloudStore? _store;
  StreamSubscription<AccountUser?>? _authSub;
  final _changes = StreamController<void>.broadcast();

  /// Fires after a pull changed local data, so open screens can reload.
  Stream<void> get changes => _changes.stream;

  /// Start following [auth]: pull on sign-in, detach on sign-out.
  void attach(AuthService auth, CloudStore Function(String uid) storeFor) {
    _authSub?.cancel();
    _authSub = auth.authStateChanges().listen((user) async {
      if (user == null) {
        _store = null;
        return;
      }
      final store = storeFor(user.uid);
      _store = store;
      await pull(store, user.uid);
    });
  }

  Future<void> pull(CloudStore store, String uid) async {
    try {
      await _pullMatches(store);
      await _pullPlayers(store, uid);
      _changes.add(null);
    } catch (_) {
      // Offline or permission problem: local data is untouched; try again on
      // the next sign-in / launch.
    }
  }

  Future<void> _pullMatches(CloudStore store) async {
    final remote = await store.loadMatches();
    final local = await games.loadHistory();
    final remoteKeys = {for (final r in remote) _key(r)};
    final localKeys = {for (final r in local) _key(r)};

    final merged = [
      ...local,
      for (final r in remote)
        if (!localKeys.contains(_key(r))) r,
    ]..sort((a, b) => b.playedAt.compareTo(a.playedAt));
    if (merged.length != local.length) await games.replaceHistory(merged);

    final missingRemotely = local
        .where((r) => !remoteKeys.contains(_key(r)))
        .toList();
    if (missingRemotely.isNotEmpty) await store.saveMatches(missingRemotely);
  }

  Future<void> _pullPlayers(CloudStore store, String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final remote = await store.loadPlayers();
    final profiles = await players.loadProfiles();
    final plain = profiles.where((p) => !p.linkedToAccount).toList();

    final firstSync = prefs.getString(_syncedUidKey) != uid;
    final merged = remote == null || firstSync
        ? [
            ...plain,
            for (final r in remote ?? const <PlayerProfile>[])
              if (!plain.any((p) => p.id == r.id)) r,
          ]
        : remote;

    // Re-read so an account profile added while we were awaiting survives.
    final account = (await players.loadProfiles()).where(
      (p) => p.linkedToAccount,
    );
    await players.replaceProfiles([...account, ...merged]);

    if (remote == null || !_sameIds(remote, merged)) {
      await store.savePlayers(merged);
    }
    await prefs.setString(_syncedUidKey, uid);
  }

  Future<void> pushPlayers() async {
    final store = _store;
    if (store == null) return;
    try {
      final profiles = await players.loadProfiles();
      await store.savePlayers(
        profiles.where((p) => !p.linkedToAccount).toList(),
      );
    } catch (_) {}
  }

  Future<void> pushMatch(GameResult result) async {
    try {
      await _store?.saveMatches([result]);
    } catch (_) {}
  }

  static String _key(GameResult r) =>
      r.playedAt.toUtc().microsecondsSinceEpoch.toString();

  static bool _sameIds(List<PlayerProfile> a, List<PlayerProfile> b) =>
      a.length == b.length && a.every(b.contains);
}
