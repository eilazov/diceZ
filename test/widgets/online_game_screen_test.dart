import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dice_zee/models/friend_profile.dart';
import 'package:dice_zee/models/online_match.dart';
import 'package:dice_zee/models/game_mode.dart';
import 'package:dice_zee/services/auth_service.dart';
import 'package:dice_zee/services/game_storage.dart';
import 'package:dice_zee/services/online_match_service.dart';
import 'package:dice_zee/widgets/dice_zee_celebration.dart';
import 'package:dice_zee/widgets/online_game_screen.dart';

import '../support/constant_random.dart';
import '../support/in_memory_online_match_store.dart';

const ada = FriendProfile(uid: 'a', name: 'Ada', code: 'AAAAAA');
const bob = FriendProfile(uid: 'b', name: 'Bob', code: 'BBBBBB');
const adaUser = AccountUser(uid: 'a', displayName: 'Ada');
const bobUser = AccountUser(uid: 'b', displayName: 'Bob');

/// Writes land locally at once (like Firestore) but only finish saving when
/// [gate] completes.
class _SlowAckStore extends InMemoryOnlineMatchStore {
  Completer<void>? gate;

  @override
  Future<void> update(OnlineMatch match) async {
    await super.update(match);
    await gate?.future;
  }
}

void main() {
  late _SlowAckStore store;
  late OnlineMatchService service;
  late String id;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = _SlowAckStore();
    service = OnlineMatchService(store);
    final m = await service.challenge(ada, bob, GameMode.standard);
    await service.accept(m, 'b');
    id = m.id;
  });

  Future<void> pump(
    WidgetTester tester,
    AccountUser user, {
    Random? random,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OnlineGameScreen(
          user: user,
          matchId: id,
          service: service,
          random: random ?? Random(1),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Ada rolls [random]'s dice from outside the widget, as her device would.
  Future<void> adaRolls(Random random) async {
    final m = (await store.get(id))!;
    await service.saveTurn(m, 'a', m.game(random: random)..roll());
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

  group('Dice Zee celebration', () {
    final celebration = find.byType(DiceZeeCelebration);

    testWidgets('the roller sees it on their own roll', (tester) async {
      await pump(tester, adaUser, random: ConstantRandom(3));

      await tester.tap(find.byKey(const ValueKey('roll_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(celebration, findsOneWidget);
      expect(find.text('YOU ROLLED'), findsOneWidget);
    });

    testWidgets("the opponent sees it when it lands in the match", (
      tester,
    ) async {
      await pump(tester, bobUser);
      expect(celebration, findsNothing);

      await adaRolls(ConstantRandom(3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(celebration, findsOneWidget);
      expect(find.text('ADA ROLLED'), findsOneWidget);
    });

    testWidgets('does not replay when the same roll is delivered again', (
      tester,
    ) async {
      await pump(tester, bobUser);
      await adaRolls(ConstantRandom(3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(celebration, findsOneWidget);
      await tester.pump(
        DiceZeeCelebration.duration + const Duration(seconds: 1),
      );
      await tester.pump();
      expect(celebration, findsNothing);

      // A re-delivery of the unchanged state (e.g. the server echoing a write).
      await store.update((await store.get(id))!);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(celebration, findsNothing);
    });

    testWidgets('stays away on an ordinary roll', (tester) async {
      await pump(tester, bobUser);
      await adaRolls(Random(1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(celebration, findsNothing);
    });

    testWidgets('does not fire for a Dice Zee already on the table at open', (
      tester,
    ) async {
      await adaRolls(ConstantRandom(3));
      await pump(tester, bobUser);
      await tester.pump(const Duration(milliseconds: 600));

      expect(celebration, findsNothing);
    });
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

  testWidgets('holding a die while the save is pending keeps the score '
      'previews on screen', (tester) async {
    await pump(tester, adaUser);
    await tester.tap(find.byKey(const ValueKey('roll_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('commit_chance')), findsOneWidget);

    store.gate = Completer<void>();
    await tester.tap(find.byKey(const ValueKey('die_0')));
    await tester.pump();

    expect(find.byKey(const ValueKey('commit_chance')), findsOneWidget);

    store.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('commit_chance')), findsOneWidget);
  });

  testWidgets('tapping a score while a save is pending does nothing, '
      'not even a haptic', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pump(tester, adaUser);
    await tester.tap(find.byKey(const ValueKey('roll_button')));
    await tester.pumpAndSettle();

    store.gate = Completer<void>();
    await tester.tap(find.byKey(const ValueKey('die_0')));
    await tester.pump();
    expect(haptics, contains('HapticFeedbackType.selectionClick'));
    haptics.clear();
    await tester.tap(find.byKey(const ValueKey('commit_chance')));
    await tester.pump();

    expect(haptics, isNot(contains('HapticFeedbackType.lightImpact')));
    expect((await store.get(id))!.game().round, 1);

    store.gate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('holding a die while the save is pending leaves Roll and the '
      'dice looking enabled', (tester) async {
    await pump(tester, adaUser);
    await tester.tap(find.byKey(const ValueKey('roll_button')));
    await tester.pumpAndSettle();

    FilledButton roll() =>
        tester.widget<FilledButton>(find.byKey(const ValueKey('roll_button')));
    expect(roll().onPressed, isNotNull);

    store.gate = Completer<void>();
    await tester.tap(find.byKey(const ValueKey('die_0')));
    await tester.pump();

    expect(roll().onPressed, isNotNull);

    store.gate!.complete();
    await tester.pumpAndSettle();
    expect(roll().onPressed, isNotNull);
  });

  testWidgets('holding a second die while the first save is pending keeps '
      'both', (tester) async {
    await pump(tester, adaUser);
    await tester.tap(find.byKey(const ValueKey('roll_button')));
    await tester.pumpAndSettle();

    store.gate = Completer<void>();
    await tester.tap(find.byKey(const ValueKey('die_0')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('die_1')));
    await tester.pump();

    final held = (await store.get(id))!.game().held;
    expect(held.take(2), [true, true]);

    store.gate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets("the opponent's rolls left are counted on the Roll button", (
    tester,
  ) async {
    await pump(tester, bobUser);
    expect(find.text('Roll · 3 left'), findsOneWidget);

    await adaRolls(Random(2));
    await tester.pumpAndSettle();

    expect(find.text('Roll · 2 left'), findsOneWidget);
  });
}
