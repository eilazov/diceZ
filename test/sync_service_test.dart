import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dice_zee/models/game_mode.dart';
import 'package:dice_zee/models/game_result.dart';
import 'package:dice_zee/models/player_profile.dart';
import 'package:dice_zee/models/score_card.dart';
import 'package:dice_zee/services/auth_service.dart';
import 'package:dice_zee/services/cloud_store.dart';
import 'package:dice_zee/services/game_storage.dart';
import 'package:dice_zee/services/player_storage.dart';
import 'package:dice_zee/services/sync_service.dart';

class FakeCloudStore implements CloudStore {
  List<PlayerProfile>? players;
  final matches = <GameResult>[];
  bool failLoads = false;

  @override
  Future<List<PlayerProfile>?> loadPlayers() async {
    if (failLoads) throw Exception('offline');
    return players;
  }

  @override
  Future<void> savePlayers(List<PlayerProfile> value) async => players = value;

  @override
  Future<List<GameResult>> loadMatches() async {
    if (failLoads) throw Exception('offline');
    return [...matches];
  }

  @override
  Future<void> saveMatches(List<GameResult> value) async {
    for (final m in value) {
      matches.removeWhere((e) => e.playedAt == m.playedAt);
      matches.add(m);
    }
  }
}

class FakeAuth implements AuthService {
  final controller = StreamController<AccountUser?>.broadcast();
  @override
  bool get appleSupported => false;
  @override
  AccountUser? get currentUser => null;
  @override
  Stream<AccountUser?> authStateChanges() => controller.stream;
  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> signInWithApple() async {}
  @override
  Future<void> signOut() async {}
}

GameResult match(int minute, {int score = 1}) => GameResult(
  playedAt: DateTime.utc(2026, 1, 1, 12, minute),
  playerCount: 2,
  players: [
    for (var p = 0; p < 2; p++)
      PlayerScore(
        categoryScores: {for (final c in ScoreCategory.values) c: score},
      ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const players = PlayerStorage();
  const games = GameStorage();
  late FakeCloudStore store;
  late SyncService sync;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = FakeCloudStore();
    sync = SyncService();
  });

  group('first pull for an account', () {
    test('unions players and matches both ways', () async {
      await players.addProfile('Local');
      await games.saveResult(match(1));
      store.players = const [PlayerProfile(id: 'r1', name: 'Remote')];
      store.matches.add(match(2));

      await sync.pull(store, 'uid1');

      final names = (await players.loadProfiles()).map((p) => p.name);
      expect(names, containsAll(['Local', 'Remote']));
      expect(
        store.players!.map((p) => p.name),
        containsAll(['Local', 'Remote']),
      );
      expect((await games.loadHistory()).map((r) => r.playedAt), [
        match(2).playedAt,
        match(1).playedAt,
      ]);
      expect(store.matches, hasLength(2));
    });

    test('never uploads the account profile', () async {
      await players.ensureAccountProfile('uid1', 'Me');
      await players.addProfile('Local');

      await sync.pull(store, 'uid1');

      expect(store.players!.map((p) => p.name), ['Local']);
      final local = await players.loadProfiles();
      expect(local.first.linkedToAccount, isTrue);
    });

    test('does not duplicate matches already on both sides', () async {
      await games.saveResult(match(1));
      store.matches.add(match(1));

      await sync.pull(store, 'uid1');

      expect(await games.loadHistory(), hasLength(1));
      expect(store.matches, hasLength(1));
    });
  });

  group('later pulls', () {
    test('the cloud player list is authoritative', () async {
      store.players = const [
        PlayerProfile(id: 'a', name: 'A'),
        PlayerProfile(id: 'b', name: 'B'),
      ];
      await sync.pull(store, 'uid1');

      store.players = const [PlayerProfile(id: 'a', name: 'A')];
      await sync.pull(store, 'uid1');

      expect((await players.loadProfiles()).map((p) => p.id), ['a']);
    });

    test('keeps the account profile', () async {
      await sync.pull(store, 'uid1');
      await players.ensureAccountProfile('uid1', 'Me');
      store.players = const [PlayerProfile(id: 'a', name: 'A')];

      await sync.pull(store, 'uid1');

      expect((await players.loadProfiles()).map((p) => p.name), ['Me', 'A']);
    });
  });

  test(
    'pull swallows connectivity errors and leaves local data alone',
    () async {
      await players.addProfile('Local');
      store.failLoads = true;

      await sync.pull(store, 'uid1');

      expect(await players.loadProfiles(), hasLength(1));
    },
  );

  group('pushing local changes', () {
    test('are no-ops while signed out', () async {
      await sync.pushPlayers();
      await sync.pushMatch(match(1));

      expect(store.players, isNull);
      expect(store.matches, isEmpty);
    });

    test('write through once attached', () async {
      final auth = FakeAuth();
      sync.attach(auth, (_) => store);
      auth.controller.add(const AccountUser(uid: 'uid1'));
      await pumpEventQueue();

      await players.addProfile('New');
      await sync.pushPlayers();
      await sync.pushMatch(match(5));

      expect(store.players!.map((p) => p.name), ['New']);
      expect(store.matches.single.playedAt, match(5).playedAt);
    });

    test('stop after sign-out', () async {
      final auth = FakeAuth();
      sync.attach(auth, (_) => store);
      auth.controller.add(const AccountUser(uid: 'uid1'));
      await pumpEventQueue();
      auth.controller.add(null);
      await pumpEventQueue();

      await sync.pushMatch(match(5));

      expect(store.matches, isEmpty);
    });
  });

  test('signing in pulls and announces the change', () async {
    store.matches.add(match(3));
    final auth = FakeAuth();
    sync.attach(auth, (_) => store);
    final changes = expectLater(sync.changes, emits(null));

    auth.controller.add(const AccountUser(uid: 'uid1'));
    await changes;

    expect(await games.loadHistory(), hasLength(1));
  });

  test('a pulled standard match keeps its mode and upper bonus', () async {
    store.matches.add(GameResult(
      playedAt: DateTime.utc(2026, 1, 1),
      playerCount: 1,
      mode: GameMode.standard,
      players: [
        PlayerScore(
          categoryScores: {for (final c in ScoreCategory.values) c: 1},
          upperBonus: 35,
        ),
      ],
    ));

    await sync.pull(store, 'uid1');

    final pulled = (await games.loadHistory()).single;
    expect(pulled.mode, GameMode.standard);
    expect(pulled.players.single.upperBonus, 35);
  });

  test('matches stored without a mode (older versions) sync as extended',
      () async {
    await games.saveResult(match(1));

    await sync.pull(store, 'uid1');

    expect(store.matches.single.mode, GameMode.extended);
  });
}
