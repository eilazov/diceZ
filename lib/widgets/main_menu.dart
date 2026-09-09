import 'package:flutter/material.dart';

import '../models/game_result.dart';
import '../services/game_storage.dart';
import 'game_screen.dart';
import 'pip_face.dart';
import 'statistics_screen.dart';
import 'version_indicator.dart';

/// App home: pick a player count and start a match, or view statistics.
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key, this.storage = const GameStorage()});

  final GameStorage storage;

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  int _count = 2;
  late final Future<List<GameResult>> _history = widget.storage.loadHistory();

  void _startGame() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(playerCount: _count),
      ),
    );
  }

  void _openStatistics() {
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
                  Column(
                    children: [
                      PipFace(
                        value: 5,
                        color: theme.colorScheme.primary,
                        size: 44,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Dice Zee',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  _BestGameLine(history: _history),
                  const SizedBox(height: 40),
                  Text(
                    'Players',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 2, label: Text('2')),
                        ButtonSegment(value: 3, label: Text('3')),
                        ButtonSegment(value: 4, label: Text('4')),
                      ],
                      selected: {_count},
                      onSelectionChanged: (s) =>
                          setState(() => _count = s.first),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const ValueKey('start_button'),
                    onPressed: _startGame,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('Start'),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _openStatistics,
                    icon: const Icon(Icons.bar_chart),
                    label: const Text('Statistics'),
                  ),
                  const SizedBox(height: 24),
                  const VersionIndicator(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Best game · N" once at least one match has been recorded; nothing before.
class _BestGameLine extends StatelessWidget {
  const _BestGameLine({required this.history});

  final Future<List<GameResult>> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<GameResult>>(
      future: history,
      builder: (context, snapshot) {
        final games = snapshot.data;
        if (games == null || games.isEmpty) return const SizedBox.shrink();
        final best = games
            .expand((g) => g.players.map((p) => p.total))
            .fold(0, (a, b) => a > b ? a : b);
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            'Best game · $best',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );
      },
    );
  }
}
