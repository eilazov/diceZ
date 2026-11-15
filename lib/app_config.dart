import 'package:flutter/foundation.dart';

/// A fixed email/password account that exists only in the Firebase emulator.
class TestUser {
  const TestUser(this.name, this.email, this.password);

  final String name;
  final String email;
  final String password;
}

/// Dev-only switches, set with `--dart-define`. Release builds ignore them.
///
/// `flutter run --dart-define=USE_EMULATOR=true` points Auth and Firestore at
/// the local Firebase emulators and offers [testUsers] on the Account page.
/// `--dart-define=EMULATOR_HOST=10.0.2.2` is needed on the Android emulator.
abstract final class AppConfig {
  static const bool useEmulator =
      !kReleaseMode && bool.fromEnvironment('USE_EMULATOR');

  static const String emulatorHost = String.fromEnvironment(
    'EMULATOR_HOST',
    defaultValue: 'localhost',
  );

  static const int authEmulatorPort = 9099;
  static const int firestoreEmulatorPort = 8080;

  static const List<TestUser> testUsers = useEmulator
      ? [
          TestUser('Ada', 'ada@test.dev', 'test1234'),
          TestUser('Bob', 'bob@test.dev', 'test1234'),
        ]
      : [];
}
