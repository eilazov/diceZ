import 'dart:math';

import 'package:flutter/material.dart';

import '../haptics.dart';
import '../models/dice_game.dart';
import '../models/game_result.dart';
import '../models/player_profile.dart';
import '../models/score_card.dart';
import '../seat_palette.dart';
import '../services/game_storage.dart';
import 'dice_row.dart';
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
    this.storage = const GameStorage(),
    this.random,
  });

  /// One entry per seat, in turn order. A null entry is a guest seat and
  /// falls back to [SeatPalette.label].
  final List<PlayerProfile?> lineup;

  final GameStorage storage;

  /// Seed source for the dice; injected in tests for determinism.
  final Random? random;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final DiceGame _game = DiceGame(
    playerCount: widget.lineup.length,
    random: widget.random,
  );
  int _rollCount = 0;
  bool _summaryShown = false;
  bool _awaitingHandoff = false;

  String _nameFor(int seat) => widget.lineup[seat]?.name ?? SeatPalette.label(seat);

  List<String> get _names =>
      [for (var p = 0; p < _game.playerCount; p++) _nameFor(p)];

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
        await widget.storage.saveResult(_buildResult());
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
        players: [
          for (var p = 0; p < _game.playerCount; p++)
            PlayerScore(
              categoryScores: {
                for (final c in ScoreCategory.values)
                  c: _game.scoreCardFor(p).scoreOf(c) ?? 0,
              },
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
                'Round ${_game.round.clamp(1, 15)} / 15',
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
              _TurnHeader(
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
              _ControlDeck(
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

/// Whose turn it is, and how many rolls they have left (as pips).
class _TurnHeader extends StatelessWidget {
  const _TurnHeader({
    required this.name,
    required this.color,
    required this.rollsRemaining,
  });

  final String name;
  final Color color;
  final int rollsRemaining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: color.withValues(alpha: 0.10),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(
            name,
            key: const ValueKey('turn_header'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          _RollsPips(remaining: rollsRemaining, color: color),
        ],
      ),
    );
  }
}

class _RollsPips extends StatelessWidget {
  const _RollsPips({required this.remaining, required this.color});

  final int remaining;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$remaining rolls left',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < remaining ? color : Colors.transparent,
                  border: Border.all(
                    color: i < remaining ? color : scheme.outline,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pinned bottom deck: the five dice plus the Roll button, in the thumb zone.
class _ControlDeck extends StatelessWidget {
  const _ControlDeck({
    required this.dice,
    required this.held,
    required this.canHold,
    required this.placeholder,
    required this.rollCount,
    required this.seatColor,
    required this.rollsRemaining,
    required this.canRoll,
    required this.awaitingCommit,
    required this.onRoll,
    required this.onToggleHold,
  });

  final List<int> dice;
  final List<bool> held;
  final bool canHold;
  final bool placeholder;
  final int rollCount;
  final Color seatColor;
  final int rollsRemaining;
  final bool canRoll;
  final bool awaitingCommit;
  final VoidCallback onRoll;
  final ValueChanged<int> onToggleHold;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final String label = canRoll
        ? 'Roll · $rollsRemaining left'
        : awaitingCommit
            ? 'Tap a category to score'
            : 'Roll';

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DiceRow(
                dice: dice,
                held: held,
                canHold: canHold,
                placeholder: placeholder,
                rollCount: rollCount,
                seatColor: seatColor,
                onToggleHold: onToggleHold,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('roll_button'),
                  onPressed: canRoll ? onRoll : null,
                  icon: const Icon(Icons.casino),
                  label: Text(label),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: canRoll ? seatColor : null,
                    foregroundColor: canRoll ? Colors.white : null,
                  ),
                ),
              ),
            ],
          ),
        ),
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
