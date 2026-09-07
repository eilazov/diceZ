import 'package:flutter/material.dart';

import 'widgets/game_screen.dart';

void main() => runApp(const DiceZeeApp());

class DiceZeeApp extends StatelessWidget {
  const DiceZeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final seed = Colors.indigo;
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
      // TODO(task 8): replace with MainMenuScreen once the menu lands.
      home: const GameScreen(playerCount: 2),
    );
  }
}
