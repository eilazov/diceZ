import 'package:flutter/material.dart';

import 'widgets/friendly_error_view.dart';
import 'widgets/main_menu.dart';
import 'scroll_behavior.dart';

void main() {
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
