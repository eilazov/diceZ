import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/player_storage.dart';

/// Sign in with Google / Apple, or carry on as a guest. Signed in, shows the
/// account and a sign-out button.
class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    this.authService,
    this.playerStorage = const PlayerStorage(),
  });

  final PlayerStorage playerStorage;

  /// Defaults to [FirebaseAuthService]; injectable for tests.
  final AuthService? authService;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final AuthService _auth = widget.authService ?? FirebaseAuthService();
  StreamSubscription<AccountUser?>? _authSub;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _syncProfile(_auth.currentUser);
    _authSub = _auth.authStateChanges().listen(_syncProfile);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  /// Signed-in accounts appear in Players (playing as themselves); signing
  /// out removes the entry again.
  Future<void> _syncProfile(AccountUser? user) {
    if (user == null) return widget.playerStorage.removeAccountProfile();
    final name = user.displayName?.trim();
    final email = user.email?.split('@').first;
    return widget.playerStorage.ensureAccountProfile(
      user.uid,
      name != null && name.isNotEmpty ? name : (email ?? 'Me'),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AuthFailure catch (failure) {
      if (mounted && !failure.cancelled) {
        setState(() => _error = failure.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: StreamBuilder<AccountUser?>(
                stream: _auth.authStateChanges(),
                initialData: _auth.currentUser,
                builder: (context, snapshot) {
                  final user = snapshot.data;
                  return user == null
                      ? _signedOut(context)
                      : _signedIn(context, user);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _signedOut(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Sign in to keep your account across devices. Playing without an '
          'account works exactly as before.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _busy ? null : () => _run(_auth.signInWithGoogle),
          icon: const Icon(Icons.login),
          label: const Text('Sign in with Google'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
        if (_auth.appleSupported) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : () => _run(_auth.signInWithApple),
            icon: const Icon(Icons.apple),
            label: const Text('Sign in with Apple'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Continue as Guest'),
        ),
      ],
    );
  }

  Widget _signedIn(BuildContext context, AccountUser user) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.account_circle, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: 12),
        if (user.displayName != null)
          Text(
            user.displayName!,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
        if (user.email != null)
          Text(
            user.email!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: _busy ? null : () => _run(_auth.signOut),
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}
