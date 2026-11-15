import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app_config.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firestore_cloud_store.dart';
import 'services/sync_service.dart';
import 'widgets/friendly_error_view.dart';
import 'widgets/main_menu.dart';
import 'scroll_behavior.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (AppConfig.useEmulator) {
    await FirebaseAuth.instance.useAuthEmulator(
      AppConfig.emulatorHost,
      AppConfig.authEmulatorPort,
    );
    FirebaseFirestore.instance.useFirestoreEmulator(
      AppConfig.emulatorHost,
      AppConfig.firestoreEmulatorPort,
    );
  }
  SyncService.instance.attach(
    FirebaseAuthService(),
    (uid) => FirestoreCloudStore(uid),
  );
  ErrorWidget.builder = (details) => FriendlyErrorView(details: details);
  runApp(const DiceZeeApp());
}

class DiceZeeApp extends StatelessWidget {
  const DiceZeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Colors.indigo;
    return MaterialApp(
      title: 'Dice Zee',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AlwaysScrollbarBehavior(),
      builder: (context, child) {
        final mediaQueryData = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQueryData.copyWith(
            textScaler: mediaQueryData.textScaler.clamp(maxScaleFactor: 1.1),
          ),
          child: child!,
        );
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainMenuScreen(),
    );
  }
}
