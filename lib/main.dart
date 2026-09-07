import 'package:flutter/material.dart';

import 'widgets/main_menu.dart';

void main() => runApp(const DiceZeeApp());

class DiceZeeApp extends StatelessWidget {
  const DiceZeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Colors.indigo;
    return MaterialApp(
      title: 'Dice Zee',
      debugShowCheckedModeBanner: false,
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
