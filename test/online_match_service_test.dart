import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:dice_zee/models/friend_profile.dart';
import 'package:dice_zee/models/game_mode.dart';
import 'package:dice_zee/models/online_match.dart';
import 'package:dice_zee/models/score_card.dart';
import 'package:dice_zee/services/online_match_service.dart';

import 'support/in_memory_online_match_store.dart';

const ada = FriendProfile(uid: 'a', name: 'Ada', code: 'AAAAAA');
const bob = FriendProfile(uid: 'b', name: 'Bob', code: 'BBBBBB');

void main() {
  late InMemoryOnlineMatchStore store;
  late OnlineMatchService service;

  setUp(() {
    store = InMemoryOnlineMatchStore();
    service = OnlineMatchService(store);
  });

  Future<OnlineMatch> active() async {
    final pending = await service.challenge(ada, bob, GameMode.standard);
    return service.accept(pending, 'b');
  }

  test('challenge creates a pending match with a fresh game', () async {
    final m = await service.challenge(ada, bob, GameMode.standard);
    expect(m.status, OnlineMatchStatus.pending);
    expect(m.players, ['a', 'b']);
    expect(m.names, ['Ada', 'Bob']);
    expect(m.mode, GameMode.standard);
    expect(m.game().round, 1);
    expect((await store.get(m.id))?.status, OnlineMatchStatus.pending);
  });

  test('only the invitee can accept', () async {
    final m = await service.challenge(ada, bob, GameMode.extended);
    expect(() => service.accept(m, 'a'), throwsStateError);
    final accepted = await service.accept(m, 'b');
    expect(accepted.status, OnlineMatchStatus.active);
  });

  test('decline or withdraw deletes a pending match', () async {
    final m = await service.challenge(ada, bob, GameMode.extended);
    await service.decline(m, 'b');
    expect(await store.get(m.id), isNull);
  });

  test('strangers cannot decline', () async {
    final m = await service.challenge(ada, bob, GameMode.extended);
    expect(() => service.decline(m, 'z'), throwsStateError);
  });

  test('seat and turn lookups', () async {
    final m = await active();
    expect(m.seatOf('a'), 0);
    expect(m.seatOf('b'), 1);
    expect(m.seatOf('z'), isNull);
    expect(m.isMyTurn('a'), isTrue);
    expect(m.isMyTurn('b'), isFalse);
  });

  test('the active player saves their turn', () async {
    final m = await active();
    final game = m.game(random: Random(1))..roll();
    await service.saveTurn(m, 'a', game);
    final stored = (await store.get(m.id))!;
    expect(stored.game().rollsRemaining, 2);
    expect(stored.game().hasRolledThisRound, isTrue);
  });

  test('the other player cannot save on your turn', () async {
    final m = await active();
    final game = m.game(random: Random(1))..roll();
    expect(() => service.saveTurn(m, 'b', game), throwsStateError);
  });

  test('finishing the last turn marks the match finished', () async {
    var m = await active();
    final game = m.game(random: Random(1));
    final cats = GameMode.standard.categories;
    for (var i = 0; i < cats.length * 2; i++) {
      game.roll();
      final mover = game.currentPlayer == 0 ? 'a' : 'b';
      game.commitScore(cats[i ~/ 2]);
      m = await service.saveTurn(m, mover, game);
    }
    expect(m.status, OnlineMatchStatus.finished);
    expect(m.finishedAt, isNotNull);

    final result = service.resultOf(m, myUid: 'a', myProfileId: 'pa');
    expect(result.playerCount, 2);
    expect(result.mode, GameMode.standard);
    expect(result.players[0].name, 'Ada');
    expect(result.players[0].profileId, 'pa');
    expect(result.players[1].profileId, isNull);
    expect(result.playedAt, m.finishedAt);
    expect(result.players[0].categoryScores[ScoreCategory.chance], isNotNull);
  });

  test('JSON round-trips', () async {
    final m = await active();
    final copy = OnlineMatch.fromJson(m.id, m.toJson());
    expect(copy.players, m.players);
    expect(copy.status, m.status);
    expect(copy.mode, m.mode);
    expect(copy.state, m.state);
  });
}
