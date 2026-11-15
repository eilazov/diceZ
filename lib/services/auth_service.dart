import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../app_config.dart';

/// The signed-in account, stripped of Firebase types.
class AccountUser {
  const AccountUser({required this.uid, this.displayName, this.email});

  final String uid;
  final String? displayName;
  final String? email;
}

/// A sign-in failure with a message that is safe to show to the player.
/// [cancelled] is true when the player just dismissed the sign-in sheet.
class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.cancelled = false});

  factory AuthFailure.fromCode(String code) {
    switch (code) {
      case 'canceled':
      case 'cancelled':
      case 'popup-closed-by-user':
      case 'web-context-canceled':
        return const AuthFailure('Sign-in cancelled.', cancelled: true);
      case 'network-request-failed':
        return const AuthFailure(
          'No connection. Check your internet and try again.',
        );
      case 'account-exists-with-different-credential':
        return const AuthFailure(
          'This email is already used with a different sign-in method.',
        );
      case 'user-disabled':
        return const AuthFailure('This account has been disabled.');
      default:
        return const AuthFailure('Sign-in failed.');
    }
  }

  final String message;
  final bool cancelled;

  @override
  String toString() => 'AuthFailure($message)';
}

/// Sign-in with Google / Apple. Guest play never touches this.
abstract class AuthService {
  bool get appleSupported;
  AccountUser? get currentUser;
  Stream<AccountUser?> authStateChanges();

  /// Throws [AuthFailure] on failure or cancellation.
  Future<void> signInWithGoogle();
  Future<void> signInWithApple();
  Future<void> signOut();

  /// Deletes the signed-in account. [cleanup] removes its server-side data
  /// first, while it can still be authorised. Throws [AuthFailure].
  Future<void> deleteAccount(Future<void> Function(String uid) cleanup);
}

/// Optional extra on an [AuthService]: sign in as a fixed [TestUser] without a
/// provider. Only offered against the Firebase emulator (see [AppConfig]).
abstract interface class EmailSignIn {
  Future<void> signInWithEmail(TestUser testUser);
}

/// Firebase-backed [AuthService]. Uses Firebase's provider flow (popup on
/// web), so no extra sign-in packages are needed.
class FirebaseAuthService implements AuthService, EmailSignIn {
  FirebaseAuthService({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  // Apple on the web needs a Services ID set up in the Apple developer
  // portal, so it is only offered on Apple platforms for now.
  bool get appleSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  AccountUser? get currentUser => _toUser(_auth.currentUser);

  @override
  Stream<AccountUser?> authStateChanges() =>
      _auth.authStateChanges().map(_toUser);

  @override
  Future<void> signInWithGoogle() => _signIn(GoogleAuthProvider());

  @override
  Future<void> signInWithApple() => _signIn(AppleAuthProvider());

  /// Signs in as [testUser], creating the account first if the emulator has
  /// never seen it. Refuses to run outside emulator mode.
  @override
  Future<void> signInWithEmail(TestUser testUser) async {
    if (!AppConfig.useEmulator) {
      throw const AuthFailure('Test sign-in is only available on emulators.');
    }
    try {
      try {
        await _auth.signInWithEmailAndPassword(
          email: testUser.email,
          password: testUser.password,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code != 'user-not-found' && e.code != 'invalid-credential') {
          rethrow;
        }
        final created = await _auth.createUserWithEmailAndPassword(
          email: testUser.email,
          password: testUser.password,
        );
        await created.user?.updateDisplayName(testUser.name);
      }
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> deleteAccount(Future<void> Function(String uid) cleanup) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _reauthenticate(user);
      await cleanup(user.uid);
      await user.delete();
    } on FirebaseAuthException catch (e) {
      final failure = AuthFailure.fromCode(e.code);
      throw failure.cancelled
          ? failure
          : const AuthFailure('Could not delete your account. Try again.');
    } catch (_) {
      throw const AuthFailure('Could not delete your account. Try again.');
    }
  }

  /// Deleting is sensitive, so confirm it is really the owner by signing in
  /// with their provider again. Accounts without one (emulator test users,
  /// who just signed in) skip this.
  Future<void> _reauthenticate(User user) async {
    final providerId = user.providerData.firstOrNull?.providerId;
    final AuthProvider? provider = switch (providerId) {
      'google.com' => GoogleAuthProvider(),
      'apple.com' => AppleAuthProvider(),
      _ => null,
    };
    if (provider == null) return;
    if (kIsWeb) {
      await user.reauthenticateWithPopup(provider);
    } else {
      await user.reauthenticateWithProvider(provider);
    }
  }

  Future<void> _signIn(AuthProvider provider) async {
    try {
      if (kIsWeb) {
        await _auth.signInWithPopup(provider);
      } else {
        await _auth.signInWithProvider(provider);
      }
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code);
    }
  }

  static AccountUser? _toUser(User? user) => user == null
      ? null
      : AccountUser(
          uid: user.uid,
          displayName: user.displayName,
          email: user.email,
        );
}
