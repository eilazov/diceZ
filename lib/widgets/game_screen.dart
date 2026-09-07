import 'dart:math';

import 'package:flutter/material.dart';

import '../models/dice_game.dart';
import '../models/game_result.dart';
import '../models/score_card.dart';
import '../services/game_storage.dart';
import 'dice_row.dart';
import 'score_card_view.dart';

/// The single stateful screen. Owns one [DiceGame] and rebuilds on every action.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    this.storage = const GameStorage(),
    this.random,
  });

  final GameStorage storage;

  /// Seed source for the game's dice; injected in tests for determinism.
  final Random? random;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late DiceGame _game = DiceGame(random: widget.random);
  int _rollCount = 0;
  bool _summaryShown = false;

  void _roll() {
    setState(() {
      _game.roll();
      _rollCount++;
    });
  }

  void _toggleHold(int index) => setState(() => _game.toggleHold(index));

  Future<void> _commit(ScoreCategory category) async {
    setState(() => _game.commitScore(category));
    if (_game.isOver && !_summaryShown) {
      _summaryShown = true;
      await widget.storage.saveResult(
        GameResult(playedAt: DateTime.now(), totalScore: _game.scoreCard.total),
      );
      if (mounted) await _showSummary();
    }
  }

  Future<void> _showSummary() async {
    final history = await widget.storage.loadHistory();
    final best = history.isEmpty
        ? _game.scoreCard.total
        : history.map((r) => r.totalScore).reduce(max);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game over'),
        content: Text(
          'You scored ${_game.scoreCard.total}.\nBest so far: $best.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _newGame();
            },
            child: const Text('New game'),
          ),
        ],
      ),
    );
  }

  void _newGame() {
    setState(() {
      _game = DiceGame(random: widget.random);
      _rollCount = 0;
      _summaryShown = false;
    });
  }

  Future<void> _showHistory() async {
    final history = await widget.storage.loadHistory();
    if (!mounted) return;
    final best = history.isEmpty
        ? 0
        : history.map((r) => r.totalScore).reduce(max);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('History'),
        content: SizedBox(
          width: double.maxFinite,
          child: history.isEmpty
              ? const Text('No games played yet.')
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final r in history)
                      ListTile(
                        dense: true,
                        leading: Text('${r.totalScore}'),
                        title: Text(_formatDate(r.playedAt)),
                        trailing: r.totalScore == best
                            ? const Icon(Icons.star, size: 18)
                            : null,
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final canRoll = _game.rollsRemaining > 0 && !_game.isOver;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dice Zee'),
        actions: [
          IconButton(
            onPressed: _showHistory,
            icon: const Icon(Icons.history),
            tooltip: 'History',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Round ${_game.round.clamp(1, 15)} / 15',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Rolls left: ${_game.rollsRemaining}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            DiceRow(
              dice: _game.dice,
              held: _game.held,
              canHold: _game.hasRolledThisRound && !_game.isOver,
              rollCount: _rollCount,
              onToggleHold: _toggleHold,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: canRoll ? _roll : null,
              icon: const Icon(Icons.casino),
              label: const Text('Roll'),
            ),
            const SizedBox(height: 16),
            ScoreCardView(
              card: _game.scoreCard,
              currentDice: _game.dice,
              canCommit: _game.hasRolledThisRound && !_game.isOver,
              onCommit: _commit,
            ),
          ],
        ),
      ),
    );
  }
}
