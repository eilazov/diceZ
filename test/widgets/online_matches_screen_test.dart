import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dice_zee/models/friend_profile.dart';
import 'package:dice_zee/models/game_mode.dart';
import 'package:dice_zee/services/auth_service.dart';
import 'package:dice_zee/services/friend_service.dart';
import 'package:dice_zee/services/online_match_service.dart';
import 'package:dice_zee/widgets/friends_screen.dart';
import 'package:dice_zee/widgets/online_game_screen.dart';
import 'package:dice_zee/widgets/online_matches_screen.dart';

import '../support/in_memory_friend_store.dart';
import '../support/in_memory_online_match_store.dart';

const ada = FriendProfile(uid: 'a', name: 'Ada', code: 'AAAAAA');
const bob = FriendProfile(uid: 'b', name: 'Bob', code: 'BBBBBB');
const bobUser = AccountUser(uid: 'b', displayName: 'Bob');
const adaUser = AccountUser(uid: 'a', displayName: 'Ada');

Future<void> pump(
  WidgetTester tester,
  OnlineMatchService service,
  AccountUser user, {
  FriendService? friendService,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: OnlineMatchesScreen(
        user: user,
        service: service,
        friendService: friendService,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late OnlineMatchService service;

  setUp(() => service = OnlineMatchService(InMemoryOnlineMatchStore()));

  testWidgets('empty state', (tester) async {
    await pump(tester, service, bobUser);
    expect(find.textContaining('Tap New game'), findsOneWidget);
  });

  testWidgets('an invite can be accepted and opens the game', (tester) async {
    await service.challenge(ada, bob, GameMode.standard);
    await pump(tester, service, bobUser);

    expect(find.text('Ada challenged you'), findsOneWidget);
    await tester.tap(find.byTooltip('Accept'));
    await tester.pumpAndSettle();

    expect(find.byType(OnlineGameScreen), findsOneWidget);
    expect(find.text('vs Ada'), findsOneWidget);
  });

  testWidgets('an invite can be declined', (tester) async {
    await service.challenge(ada, bob, GameMode.standard);
    await pump(tester, service, bobUser);

    await tester.tap(find.byTooltip('Decline'));
    await tester.pumpAndSettle();

    expect(find.text('Ada challenged you'), findsNothing);
  });

  testWidgets('the challenger sees a sent invite and can withdraw it', (
    tester,
  ) async {
    await service.challenge(ada, bob, GameMode.extended);
    await pump(tester, service, adaUser);

    expect(find.text('Waiting for a reply'), findsOneWidget);
    await tester.tap(find.byTooltip('Withdraw'));
    await tester.pumpAndSettle();

    expect(find.text('Waiting for a reply'), findsNothing);
  });

  testWidgets('active matches show whose turn it is', (tester) async {
    final m = await service.challenge(ada, bob, GameMode.extended);
    await service.accept(m, 'b');

    await pump(tester, service, adaUser);
    expect(find.text('Your turn'), findsOneWidget);

    await pump(tester, service, bobUser);
    expect(find.text('Their turn'), findsOneWidget);
  });

  group('new game and friends', () {
    late FriendService friends;

    /// Ada and Bob are friends; returns nothing, state lives in [friends].
    Future<void> befriend() async {
      final adaProfile = await friends.myProfile('a', 'Ada');
      final bobProfile = await friends.myProfile('b', 'Bob');
      await friends.sendRequest(adaProfile, bobProfile.code);
      await friends.accept(bobProfile, adaProfile);
    }

    setUp(
      () => friends = FriendService(InMemoryFriendStore(), random: Random(5)),
    );

    testWidgets('new game challenges a friend in the chosen mode', (
      tester,
    ) async {
      await befriend();
      await pump(tester, service, adaUser, friendService: friends);

      await tester.tap(find.byKey(const ValueKey('new_game_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bob'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Extended'));
      await tester.pumpAndSettle();

      final bobs = await service.watchFor('b').first;
      expect(bobs.single.mode, GameMode.extended);
      expect(bobs.single.names, ['Ada', 'Bob']);
      expect(find.text('Challenge sent to Bob.'), findsOneWidget);
    });

    testWidgets('new game without friends points to Friends', (tester) async {
      await pump(tester, service, adaUser, friendService: friends);

      await tester.tap(find.byKey(const ValueKey('new_game_button')));
      await tester.pumpAndSettle();

      expect(find.text('Add a friend first'), findsOneWidget);
      await tester.tap(find.text('Open Friends'));
      await tester.pumpAndSettle();
      expect(find.byType(FriendsScreen), findsOneWidget);
    });

    testWidgets('the friends action opens the friends screen', (tester) async {
      await pump(tester, service, adaUser, friendService: friends);

      await tester.tap(find.byKey(const ValueKey('friends_action')));
      await tester.pumpAndSettle();

      expect(find.byType(FriendsScreen), findsOneWidget);
    });
  });
}
