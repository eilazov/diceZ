import 'dart:async';

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dice_zee/services/auth_service.dart';
import 'package:dice_zee/services/friend_service.dart';
import 'package:dice_zee/widgets/friends_screen.dart';
import 'package:dice_zee/services/player_storage.dart';
import 'package:dice_zee/widgets/account_screen.dart';

import '../support/in_memory_friend_store.dart';

class FakeAuthService implements AuthService {
  FakeAuthService({this.user, this.appleSupported = true});

  final _controller = StreamController<AccountUser?>.broadcast();
  AccountUser? user;
  Object? failWith;
  final calls = <String>[];

  @override
  final bool appleSupported;

  @override
  AccountUser? get currentUser => user;

  @override
  Stream<AccountUser?> authStateChanges() => _controller.stream;

  Future<void> _signIn(String provider) async {
    calls.add(provider);
    if (failWith != null) throw failWith!;
    user = const AccountUser(uid: 'u1', displayName: 'Ada', email: 'a@b.c');
    _controller.add(user);
  }

  @override
  Future<void> signInWithGoogle() => _signIn('google');

  @override
  Future<void> signInWithApple() => _signIn('apple');

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    user = null;
    _controller.add(null);
  }
}

const storage = PlayerStorage();

Future<void> pumpScreen(WidgetTester tester, FakeAuthService auth) async {
  await tester.pumpWidget(MaterialApp(home: AccountScreen(authService: auth)));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('signed out: offers Google, Apple and guest', (tester) async {
    await pumpScreen(tester, FakeAuthService());

    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Sign in with Apple'), findsOneWidget);
    expect(find.text('Continue as Guest'), findsOneWidget);
  });

  testWidgets('hides Apple where it is unsupported', (tester) async {
    await pumpScreen(tester, FakeAuthService(appleSupported: false));

    expect(find.text('Sign in with Apple'), findsNothing);
  });

  testWidgets('Continue as Guest pops without touching auth', (tester) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AccountScreen(authService: auth),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue as Guest'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountScreen), findsNothing);
    expect(auth.calls, isEmpty);
  });

  testWidgets('Google sign-in switches to the signed-in view', (tester) async {
    final auth = FakeAuthService();
    await pumpScreen(tester, auth);

    await tester.tap(find.text('Sign in with Google'));
    await tester.pumpAndSettle();

    expect(auth.calls, ['google']);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('a@b.c'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('shows the failure message inline', (tester) async {
    final auth = FakeAuthService()
      ..failWith = const AuthFailure('No connection. Try again.');
    await pumpScreen(tester, auth);

    await tester.tap(find.text('Sign in with Apple'));
    await tester.pumpAndSettle();

    expect(find.text('No connection. Try again.'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
  });

  testWidgets('a cancelled sign-in shows no error', (tester) async {
    final auth = FakeAuthService()
      ..failWith = const AuthFailure('Cancelled.', cancelled: true);
    await pumpScreen(tester, auth);

    await tester.tap(find.text('Sign in with Google'));
    await tester.pumpAndSettle();

    expect(find.text('Cancelled.'), findsNothing);
  });

  testWidgets('signed in: Sign out returns to the sign-in options', (
    tester,
  ) async {
    final auth = FakeAuthService(
      user: const AccountUser(uid: 'u1', displayName: 'Ada', email: 'a@b.c'),
    );
    await pumpScreen(tester, auth);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(auth.calls, ['signOut']);
    expect(find.text('Sign in with Google'), findsOneWidget);
  });

  testWidgets(
    'signing in adds the account to Players; signing out removes it',
    (tester) async {
      final auth = FakeAuthService();
      await pumpScreen(tester, auth);

      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();

      var profiles = await storage.loadProfiles();
      expect(profiles.single.name, 'Ada');
      expect(profiles.single.linkedToAccount, isTrue);

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      profiles = await storage.loadProfiles();
      expect(profiles, isEmpty);
    },
  );

  testWidgets('opening while already signed in ensures the profile', (
    tester,
  ) async {
    final auth = FakeAuthService(
      user: const AccountUser(uid: 'u1', displayName: 'Ada', email: 'a@b.c'),
    );
    await pumpScreen(tester, auth);

    expect((await storage.loadProfiles()).single.name, 'Ada');
  });

  testWidgets('signed in: shows friend code and opens Friends', (tester) async {
    final service = FriendService(InMemoryFriendStore(), random: Random(2));
    final auth = FakeAuthService(
      user: const AccountUser(uid: 'u1', displayName: 'Ada', email: 'a@b.c'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AccountScreen(authService: auth, friendService: service),
      ),
    );
    await tester.pumpAndSettle();

    final me = await service.myProfile('u1', 'Ada');
    expect(find.text(me.code), findsOneWidget);

    await tester.tap(find.text('Friends'));
    await tester.pumpAndSettle();

    expect(find.byType(FriendsScreen), findsOneWidget);
  });
}
