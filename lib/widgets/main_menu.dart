import 'package:flutter/material.dart';

import 'game_screen.dart';
import 'statistics_screen.dart';

/// App home: start a 2–4 player game or view statistics.
class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  void _startGame(BuildContext context, int playerCount) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(playerCount: playerCount),
      ),
    );
  }

  void _openStatistics(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StatisticsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Dice Zee',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall,
                  ),
                  const SizedBox(height: 40),
                  Text('New game', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  for (final count in [2, 3, 4])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: FilledButton.tonal(
                        onPressed: () => _startGame(context, count),
                        child: Text('$count Players'),
                      ),
                    ),
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    onPressed: () => _openStatistics(context),
                    icon: const Icon(Icons.bar_chart),
                    label: const Text('Statistics'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
