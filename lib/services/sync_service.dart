import 'dart:async';

import '../models/game_result.dart';
import 'auth_service.dart';
import 'cloud_store.dart';
import 'game_storage.dart';

/// Keeps local match history mirrored to the signed-in account's
/// [CloudStore]. Local storage stays the source of truth, so everything works
/// offline and as a guest; sync failures are swallowed and retried on the
/// next pull.
///
/// - [pull] (sign-in / app start): merge cloud into local, upload what the
///   cloud lacks.
/// - [pushMatch]: write-through after a local change.
class SyncService {
  SyncService({this.games = const GameStorage()});

  /// The instance the app wires up in `main()`.
  static final SyncService instance = SyncService();

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

  Future<void> pushMatch(GameResult result) async {
    try {
      await _store?.saveMatches([result]);
    } catch (_) {}
  }

  static String _key(GameResult r) =>
      r.playedAt.toUtc().microsecondsSinceEpoch.toString();
}
