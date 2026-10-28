import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dice_zee/models/friend_profile.dart';
import 'package:dice_zee/models/game_mode.dart';
import 'package:dice_zee/services/auth_service.dart';
import 'package:dice_zee/services/online_match_service.dart';
import 'package:dice_zee/widgets/online_game_screen.dart';
import 'package:dice_zee/widgets/online_matches_screen.dart';

import '../support/in_memory_online_match_store.dart';

const ada = FriendProfile(uid: 'a', name: 'Ada', code: 'AAAAAA');
const bob = FriendProfile(uid: 'b', name: 'Bob', code: 'BBBBBB');
const bobUser = AccountUser(uid: 'b', displayName: 'Bob');
const adaUser = AccountUser(uid: 'a', displayName: 'Ada');

Future<void> pump(
  WidgetTester tester,
  OnlineMatchService service,
  AccountUser user,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: OnlineMatchesScreen(user: user, service: service),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late OnlineMatchService service;

  setUp(() => service = OnlineMatchService(InMemoryOnlineMatchStore()));

  testWidgets('empty state', (tester) async {
    await pump(tester, service, bobUser);
    expect(find.textContaining('No online games yet'), findsOneWidget);
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
}
