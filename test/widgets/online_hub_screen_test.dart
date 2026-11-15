import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dice_zee/services/auth_service.dart';
import 'package:dice_zee/services/online_match_service.dart';
import 'package:dice_zee/widgets/account_screen.dart';
import 'package:dice_zee/widgets/online_hub_screen.dart';
import 'package:dice_zee/widgets/online_matches_screen.dart';

import '../support/in_memory_online_match_store.dart';

class _Auth implements AuthService {
  _Auth({this.user});

  final controller = StreamController<AccountUser?>.broadcast();
  AccountUser? user;
  int streamRequests = 0;

  @override
  bool get appleSupported => false;
  @override
  AccountUser? get currentUser => user;
  @override
  Stream<AccountUser?> authStateChanges() {
    streamRequests++;
    return controller.stream;
  }

  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> signInWithApple() async {}
  @override
  Future<void> signOut() async {}
}

const _ada = AccountUser(uid: 'a', displayName: 'Ada');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, _Auth auth) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OnlineHubScreen(
          authService: auth,
          matchService: OnlineMatchService(InMemoryOnlineMatchStore()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('signed out: asks to sign in and opens Account', (tester) async {
    await pump(tester, _Auth());

    expect(find.text('Online Game'), findsOneWidget);
    expect(find.text('Sign in to play online with friends'), findsOneWidget);
    expect(find.byType(OnlineMatchesScreen), findsNothing);

    await tester.tap(find.byKey(const ValueKey('hub_sign_in')));
    await tester.pumpAndSettle();

    expect(find.byType(AccountScreen), findsOneWidget);
  });

  testWidgets('signed in: shows the online games list', (tester) async {
    await pump(tester, _Auth(user: _ada));

    expect(find.byType(OnlineMatchesScreen), findsOneWidget);
    expect(find.text('Online Game'), findsOneWidget);
    expect(find.byKey(const ValueKey('new_game_button')), findsOneWidget);
  });

  testWidgets('signing out while open falls back to the prompt', (
    tester,
  ) async {
    final auth = _Auth(user: _ada);
    await pump(tester, auth);

    auth.controller.add(null);
    await tester.pumpAndSettle();

    expect(find.byType(OnlineMatchesScreen), findsNothing);
    expect(find.byKey(const ValueKey('hub_sign_in')), findsOneWidget);
  });

  testWidgets('signing in while open reveals the list', (tester) async {
    final auth = _Auth();
    await pump(tester, auth);

    auth.controller.add(_ada);
    await tester.pumpAndSettle();

    expect(find.byType(OnlineMatchesScreen), findsOneWidget);
  });

  testWidgets('follows auth through one stream, not one per rebuild', (
    tester,
  ) async {
    final auth = _Auth();
    await pump(tester, auth);

    auth.controller.add(_ada);
    await tester.pumpAndSettle();
    auth.controller.add(null);
    await tester.pumpAndSettle();

    expect(auth.streamRequests, 1);
  });
}
