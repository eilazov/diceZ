import 'dart:math';

import 'package:flutter/material.dart';

import '../haptics.dart';
import '../models/dice_game.dart';
import '../models/game_result.dart';
import '../models/score_card.dart';
import '../services/game_storage.dart';
import 'bottom_padding.dart';
import 'dice_row.dart';
import 'score_table.dart';

/// The playing screen for a 2–4 player hot-seat match. Owns one [DiceGame] and
/// rebuilds on every action.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.playerCount,
    this.storage = const GameStorage(),
    this.random,
  });

  final int playerCount;
  final GameStorage storage;

  /// Seed source for the dice; injected in tests for determinism.
  final Random? random;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final DiceGame _game = DiceGame(
    playerCount: widget.playerCount,
    random: widget.random,
  );
  int _rollCount = 0;
  bool _summaryShown = false;

  void _roll() {
    AppHaptics.roll();
    setState(() {
      _game.roll();
      _rollCount++;
    });
  }

  void _toggleHold(int index) {
    AppHaptics.hold();
    setState(() => _game.toggleHold(index));
  }

  Future<void> _commit(ScoreCategory category) async {
    AppHaptics.commit();
    setState(() {
      _game.commitScore(category);
      _rollCount++;
    });
    if (_game.isOver && !_summaryShown) {
      _summaryShown = true;
      AppHaptics.gameOver();
      await widget.storage.saveResult(_buildResult());
      if (mounted) await _showSummary();
    }
  }

  GameResult _buildResult() => GameResult(
        playedAt: DateTime.now(),
        playerCount: _game.playerCount,
        players: [
          for (var p = 0; p < _game.playerCount; p++)
            PlayerScore(categoryScores: {
              for (final c in ScoreCategory.values)
                c: _game.scoreCardFor(p).scoreOf(c) ?? 0,
            }),
        ],
      );

  Future<void> _showSummary() async {
    final standings = _game.standings;
    final ranking = List.generate(_game.playerCount, (p) => p)
      ..sort((a, b) => standings[b].compareTo(standings[a]));
    final winner = _game.winner;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game over'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              winner == null ? "It's a tie!" : 'Player ${winner + 1} wins!',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            for (final p in ranking)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('Player ${p + 1}: ${standings[p]}'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // dialog
              Navigator.of(context).pop(); // back to menu
            },
            child: const Text('Back to menu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canRoll = _game.rollsRemaining > 0 && !_game.isOver;
    final canAct = _game.hasRolledThisRound && !_game.isOver;

    return Scaffold(
      appBar: AppBar(title: const Text('Dice Zee')),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: BottomPadding.of(context)),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                "Player ${_game.currentPlayer + 1}'s turn",
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Round ${_game.round.clamp(1, 15)} / 15'),
                  Text('Rolls left: ${_game.rollsRemaining}'),
                ],
              ),
            ),
            DiceRow(
              dice: _game.dice,
              held: _game.held,
              canHold: canAct,
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
            ScoreTable(
              cards: _game.scoreCards,
              currentPlayer: _game.currentPlayer,
              currentDice: _game.dice,
              canCommit: canAct,
              onCommit: _commit,
            ),
          ],
        ),
      ),
    );
  }
}
