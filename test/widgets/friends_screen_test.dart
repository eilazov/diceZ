import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dice_zee/models/friend_profile.dart';
import 'package:dice_zee/services/auth_service.dart';
import 'package:dice_zee/services/friend_service.dart';
import 'package:dice_zee/services/online_match_service.dart';
import 'package:dice_zee/models/game_mode.dart';
import 'package:dice_zee/widgets/friends_screen.dart';

import '../support/in_memory_friend_store.dart';
import '../support/in_memory_online_match_store.dart';

const ada = AccountUser(uid: 'a', displayName: 'Ada');

Future<(FriendService, FriendProfile)> setUpOther(
  InMemoryFriendStore store,
) async {
  final service = FriendService(store, random: Random(5));
  final bob = await service.myProfile('b', 'Bob');
  return (service, bob);
}

Future<void> pumpScreen(WidgetTester tester, FriendService service) async {
  await tester.pumpWidget(
    MaterialApp(
      home: FriendsScreen(user: ada, service: service),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows my friend code', (tester) async {
    final store = InMemoryFriendStore();
    final service = FriendService(store, random: Random(5));
    await pumpScreen(tester, service);

    final me = await service.myProfile('a', 'Ada');
    expect(find.text(me.code), findsOneWidget);
  });

  testWidgets('adding by code sends a request', (tester) async {
    final store = InMemoryFriendStore();
    final (service, bob) = await setUpOther(store);
    await pumpScreen(tester, service);

    await tester.enterText(find.byType(TextField), bob.code);
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Request sent to Bob'), findsOneWidget);
    expect((await service.load('b')).incoming.single.uid, 'a');
  });

  testWidgets('unknown code shows an error', (tester) async {
    final store = InMemoryFriendStore();
    final service = FriendService(store, random: Random(5));
    await pumpScreen(tester, service);

    await tester.enterText(find.byType(TextField), 'AAAAAA');
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();

    expect(find.text('No player has that code.'), findsOneWidget);
  });

  testWidgets('incoming request can be accepted', (tester) async {
    final store = InMemoryFriendStore();
    final (service, bob) = await setUpOther(store);
    final me = await service.myProfile('a', 'Ada');
    await service.sendRequest(bob, me.code);
    await pumpScreen(tester, service);

    expect(find.text('Bob'), findsOneWidget);
    await tester.tap(find.byTooltip('Accept'));
    await tester.pumpAndSettle();

    expect((await service.load('a')).friends.single.uid, 'b');
    expect(find.byTooltip('Accept'), findsNothing);
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets('incoming request can be declined', (tester) async {
    final store = InMemoryFriendStore();
    final (service, bob) = await setUpOther(store);
    final me = await service.myProfile('a', 'Ada');
    await service.sendRequest(bob, me.code);
    await pumpScreen(tester, service);

    await tester.tap(find.byTooltip('Decline'));
    await tester.pumpAndSettle();

    expect((await service.load('a')).friends, isEmpty);
    expect(find.text('Bob'), findsNothing);
  });

  testWidgets('a friend can be challenged', (tester) async {
    final store = InMemoryFriendStore();
    final (service, bob) = await setUpOther(store);
    final me = await service.myProfile('a', 'Ada');
    await service.sendRequest(bob, me.code);
    await service.accept(me, bob);
    final matches = InMemoryOnlineMatchStore();
    await tester.pumpWidget(
      MaterialApp(
        home: FriendsScreen(
          user: ada,
          service: service,
          onlineService: OnlineMatchService(matches),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Challenge'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Standard'));
    await tester.pumpAndSettle();

    expect(find.text('Challenge sent to Bob.'), findsOneWidget);
    final sent = matches.matches.values.single;
    expect(sent.players, ['a', 'b']);
    expect(sent.mode, GameMode.standard);
  });
}
