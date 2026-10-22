import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

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
}

/// Firebase-backed [AuthService]. Uses Firebase's provider flow (popup on
/// web), so no extra sign-in packages are needed.
class FirebaseAuthService implements AuthService {
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

  @override
  Future<void> signOut() => _auth.signOut();

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
