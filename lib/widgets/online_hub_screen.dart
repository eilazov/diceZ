import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/friend_service.dart';
import '../services/online_match_service.dart';
import 'account_screen.dart';
import 'online_matches_screen.dart';

/// Entry point for online play: the matches list when signed in, a sign-in
/// prompt otherwise. Follows sign-in / sign-out while open.
class OnlineHubScreen extends StatefulWidget {
  const OnlineHubScreen({
    super.key,
    this.authService,
    this.matchService,
    this.friendService,
  });

  /// Defaults to [FirebaseAuthService]; injectable for tests.
  final AuthService? authService;
  final OnlineMatchService? matchService;
  final FriendService? friendService;

  @override
  State<OnlineHubScreen> createState() => _OnlineHubScreenState();
}

class _OnlineHubScreenState extends State<OnlineHubScreen> {
  late final AuthService _auth = widget.authService ?? FirebaseAuthService();

  void _openAccount() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => AccountScreen(authService: _auth)));

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AccountUser?>(
      stream: _auth.authStateChanges(),
      initialData: _auth.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user != null) {
          return OnlineMatchesScreen(
            key: ValueKey(user.uid),
            user: user,
            service: widget.matchService,
            friendService: widget.friendService,
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Online games')),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Sign in to play online with friends',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const ValueKey('hub_sign_in'),
                      onPressed: _openAccount,
                      child: const Text('Sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
