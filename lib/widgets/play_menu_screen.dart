import 'package:flutter/material.dart';

import '../models/game_mode.dart';
import '../models/player_profile.dart';
import '../services/player_storage.dart';
import 'game_screen.dart';
import 'player_select_screen.dart';

/// Pick a player count and a rule set, then start a match.
class PlayMenuScreen extends StatefulWidget {
  const PlayMenuScreen({super.key, this.playerStorage = const PlayerStorage()});

  final PlayerStorage playerStorage;

  @override
  State<PlayMenuScreen> createState() => _PlayMenuScreenState();
}

class _PlayMenuScreenState extends State<PlayMenuScreen> {
  int _count = 2;
  GameMode _mode = GameMode.standard;

  Future<void> _start() async {
    final profiles = await widget.playerStorage.loadProfiles();
    if (!mounted) return;

    if (profiles.isEmpty) {
      _openGame(List<PlayerProfile?>.filled(_count, null));
      return;
    }
    if (profiles.length == 1) {
      _openGame([profiles.single, for (var i = 1; i < _count; i++) null]);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerSelectScreen(playerCount: _count, mode: _mode),
      ),
    );
  }

  void _openGame(List<PlayerProfile?> lineup) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(lineup: lineup, mode: _mode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('Play')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Player Count',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge?.copyWith(color: muted),
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
                    Text(
                      'Game Mode',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge?.copyWith(color: muted),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: SegmentedButton<GameMode>(
                        key: const ValueKey('mode_selector'),
                        segments: [
                          for (final mode in GameMode.values)
                            ButtonSegment(value: mode, label: Text(mode.label)),
                        ],
                        selected: {_mode},
                        onSelectionChanged: (s) =>
                            setState(() => _mode = s.first),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _RulesSummary(mode: _mode),
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const ValueKey('start_button'),
                      onPressed: _start,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: const Text('Start'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RulesSummary extends StatelessWidget {
  const _RulesSummary({required this.mode});

  final GameMode mode;

  static const _standard = [
    '13 rounds: ones–sixes, three and four of a kind, full house, '
        'straights, Dice Zee, chance',
    'Bonus +35 for 63 or more in ones–sixes',
    'Full house 25 · small straight 30 · large straight 40 · Dice Zee 50',
    'Once the Dice Zee box is filled, another Dice Zee scores 50 in any '
        'open box',
  ];

  static const _extended = [
    '15 rounds: adds one pair and two pairs',
    'Full house 30 · small straight 40 · large straight 50 · Dice Zee 100',
    'No upper bonus, no jokers',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = mode == GameMode.standard ? _standard : _extended;
    return Container(
      key: ValueKey('rules_${mode.name}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text(line, style: theme.textTheme.bodySmall)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
