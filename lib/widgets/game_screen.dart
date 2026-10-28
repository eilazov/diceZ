import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../haptics.dart';
import '../models/dice_game.dart';
import '../models/game_mode.dart';
import '../models/game_result.dart';
import '../models/player_profile.dart';
import '../models/score_card.dart';
import '../seat_palette.dart';
import '../services/game_storage.dart';
import '../services/sync_service.dart';
import 'game_controls.dart';
import 'results_screen.dart';
import 'score_table.dart';

/// The playing screen for a 2–4 player hot-seat match. Owns one [DiceGame] and
/// rebuilds on every action.
///
/// Layout is three zones: a fixed turn header, the scrolling shared score
/// table, and a pinned control deck (dice + Roll) in the thumb zone. Between
/// turns a full-screen handoff cover asks the next player to get ready.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.lineup,
    this.mode = GameMode.extended,
    this.storage = const GameStorage(),
    this.random,
  });

  /// One entry per seat, in turn order. A null entry is a guest seat and
  /// falls back to [SeatPalette.label].
  final List<PlayerProfile?> lineup;

  /// The rule set for this match.
  final GameMode mode;

  final GameStorage storage;

  /// Seed source for the dice; injected in tests for determinism.
  final Random? random;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final DiceGame _game = DiceGame(
    playerCount: widget.lineup.length,
    mode: widget.mode,
    random: widget.random,
  );
  int _rollCount = 0;
  bool _summaryShown = false;
  bool _awaitingHandoff = false;

  String _nameFor(int seat) =>
      widget.lineup[seat]?.name ?? SeatPalette.label(seat);

  List<String> get _names => [
    for (var p = 0; p < _game.playerCount; p++) _nameFor(p),
  ];

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

    if (_game.isOver) {
      if (!_summaryShown) {
        _summaryShown = true;
        AppHaptics.gameOver();
        final result = _buildResult();
        await widget.storage.saveResult(result);
        unawaited(SyncService.instance.pushMatch(result));
        if (mounted) await _showResults();
      }
      return;
    }

    AppHaptics.hold();
    setState(() => _awaitingHandoff = true);
  }

  GameResult _buildResult() => GameResult(
    playedAt: DateTime.now(),
    playerCount: _game.playerCount,
    mode: widget.mode,
    players: [
      for (var p = 0; p < _game.playerCount; p++)
        PlayerScore(
          categoryScores: {
            for (final c in widget.mode.categories)
              c: _game.scoreCardFor(p).scoreOf(c) ?? 0,
          },
          upperBonus: _game.scoreCardFor(p).upperBonus,
          profileId: widget.lineup[p]?.id,
          name: widget.lineup[p]?.name,
        ),
    ],
  );

  Future<void> _showResults() async {
    final action = await Navigator.of(context).push<ResultsAction>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ResultsScreen(
          standings: _game.standings,
          winner: _game.winner,
          names: _names,
        ),
      ),
    );
    if (!mounted) return;

    if (action == ResultsAction.rematch) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => GameScreen(
            lineup: widget.lineup,
            mode: widget.mode,
            storage: widget.storage,
          ),
        ),
      );
    } else {
      Navigator.of(context).pop(); // back to the menu
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seat = _game.currentPlayer;
    final seatColor = SeatPalette.color(seat);
    final canRoll = _game.rollsRemaining > 0 && !_game.isOver;
    final canAct = _game.hasRolledThisRound && !_game.isOver;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dice Zee'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Round ${_game.round.clamp(1, _game.roundCount)} / ${_game.roundCount}',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              TurnHeader(
                name: _nameFor(seat),
                color: seatColor,
                rollsRemaining: _game.rollsRemaining,
              ),
              Expanded(
                child: Scrollbar(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    child: ScoreTable(
                      cards: _game.scoreCards,
                      currentPlayer: seat,
                      currentDice: _game.dice,
                      canCommit: canAct,
                      onCommit: _commit,
                    ),
                  ),
                ),
              ),
              ControlDeck(
                dice: _game.dice,
                held: _game.held,
                canHold: canAct,
                placeholder: !_game.hasRolledThisRound,
                rollCount: _rollCount,
                seatColor: seatColor,
                rollsRemaining: _game.rollsRemaining,
                canRoll: canRoll,
                awaitingCommit: !canRoll && canAct,
                onRoll: _roll,
                onToggleHold: _toggleHold,
              ),
            ],
          ),
          if (_awaitingHandoff)
            _HandoffCover(
              name: _nameFor(seat),
              color: seatColor,
              onReady: () => setState(() => _awaitingHandoff = false),
            ),
        ],
      ),
    );
  }
}

/// Full-screen "pass the phone" cover shown between turns.
class _HandoffCover extends StatelessWidget {
  const _HandoffCover({
    required this.name,
    required this.color,
    required this.onReady,
  });

  final String name;
  final Color color;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: Material(
        color: color.withValues(alpha: 0.97),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.front_hand, size: 56, color: Colors.white),
                const SizedBox(height: 24),
                Text(
                  'Pass the phone to',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  key: const ValueKey('handoff_seat'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 40),
                FilledButton(
                  key: const ValueKey('handoff_ready'),
                  onPressed: onReady,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: color,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Start turn'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
