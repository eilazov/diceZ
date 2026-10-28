import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dice_zee/models/friend_profile.dart';
import 'package:dice_zee/models/game_mode.dart';
import 'package:dice_zee/services/auth_service.dart';
import 'package:dice_zee/services/game_storage.dart';
import 'package:dice_zee/services/online_match_service.dart';
import 'package:dice_zee/widgets/online_game_screen.dart';

import '../support/in_memory_online_match_store.dart';

const ada = FriendProfile(uid: 'a', name: 'Ada', code: 'AAAAAA');
const bob = FriendProfile(uid: 'b', name: 'Bob', code: 'BBBBBB');
const adaUser = AccountUser(uid: 'a', displayName: 'Ada');
const bobUser = AccountUser(uid: 'b', displayName: 'Bob');

void main() {
  late InMemoryOnlineMatchStore store;
  late OnlineMatchService service;
  late String id;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = InMemoryOnlineMatchStore();
    service = OnlineMatchService(store);
    final m = await service.challenge(ada, bob, GameMode.standard);
    await service.accept(m, 'b');
    id = m.id;
  });

  Future<void> pump(WidgetTester tester, AccountUser user) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OnlineGameScreen(
          user: user,
          matchId: id,
          service: service,
          random: Random(1),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('on your turn, Roll writes the new state', (tester) async {
    await pump(tester, adaUser);

    expect(find.text('Your turn'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('roll_button')));
    await tester.pumpAndSettle();

    final game = (await store.get(id))!.game();
    expect(game.rollsRemaining, 2);
    expect(game.hasRolledThisRound, isTrue);
  });

  testWidgets("on the opponent's turn the controls are disabled", (
    tester,
  ) async {
    await pump(tester, bobUser);

    expect(find.text("Ada's turn"), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('roll_button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('a move by the opponent appears live', (tester) async {
    await pump(tester, bobUser);

    final m = (await store.get(id))!;
    final game = m.game(random: Random(2))..roll();
    await service.saveTurn(m, 'a', game);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('roll_button')), findsOneWidget);
    expect((await store.get(id))!.game().rollsRemaining, 2);
  });

  testWidgets('a finished match is saved to local history once', (
    tester,
  ) async {
    var m = (await store.get(id))!;
    final game = m.game(random: Random(1));
    final cats = GameMode.standard.categories;
    for (var i = 0; i < cats.length * 2; i++) {
      game.roll();
      final mover = game.currentPlayer == 0 ? 'a' : 'b';
      game.commitScore(cats[i ~/ 2]);
      m = await service.saveTurn(m, mover, game);
    }

    await pump(tester, adaUser);
    await pump(tester, adaUser);

    final history = await const GameStorage().loadHistory();
    expect(history, hasLength(1));
    expect(history.single.players[0].name, 'Ada');
  });
}
