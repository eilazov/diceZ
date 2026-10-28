import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../haptics.dart';
import '../models/dice_game.dart';
import '../models/online_match.dart';
import '../models/score_card.dart';
import '../seat_palette.dart';
import '../services/auth_service.dart';
import '../services/firestore_online_match_store.dart';
import '../services/game_storage.dart';
import '../services/online_match_service.dart';
import '../services/player_storage.dart';
import 'game_controls.dart';
import 'results_screen.dart';
import 'score_table.dart';

/// One online match. Renders whatever the shared document says; the controls
/// only work on your own turn, and every action writes the new state back.
class OnlineGameScreen extends StatefulWidget {
  const OnlineGameScreen({
    super.key,
    required this.user,
    required this.matchId,
    this.service,
    this.storage = const GameStorage(),
    this.playerStorage = const PlayerStorage(),
    this.random,
  });

  final AccountUser user;
  final String matchId;

  /// Defaults to a Firestore-backed service; injectable for tests.
  final OnlineMatchService? service;
  final GameStorage storage;
  final PlayerStorage playerStorage;
  final Random? random;

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen> {
  late final OnlineMatchService _service =
      widget.service ?? OnlineMatchService(FirestoreOnlineMatchStore());
  late final Stream<OnlineMatch?> _stream = _service.watch(widget.matchId);
  bool _finishHandled = false;
  bool _busy = false;

  Future<void> _act(
    OnlineMatch match,
    void Function(DiceGame game) apply,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final game = match.game(random: widget.random);
      apply(game);
      await _service.saveTurn(match, widget.user.uid, game);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't save your move. Try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleFinished(OnlineMatch match) async {
    if (_finishHandled) return;
    _finishHandled = true;
    final profiles = await widget.playerStorage.loadProfiles();
    final linked = profiles.where((p) => p.linkedToAccount).firstOrNull;
    final result = _service.resultOf(
      match,
      myUid: widget.user.uid,
      myProfileId: linked?.id,
    );
    final history = await widget.storage.loadHistory();
    if (!history.any((r) => r.playedAt == result.playedAt)) {
      await widget.storage.saveResult(result);
    }
    if (!mounted) return;
    AppHaptics.gameOver();
    final game = match.game();
    await Navigator.of(context).push<ResultsAction>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ResultsScreen(
          standings: game.standings,
          winner: game.winner,
          names: match.names,
        ),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<OnlineMatch?>(
      stream: _stream,
      builder: (context, snapshot) {
        final match = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _shell(const Center(child: CircularProgressIndicator()));
        }
        if (match == null) {
          return _shell(
            const Center(child: Text('This match no longer exists.')),
          );
        }
        if (match.status == OnlineMatchStatus.pending) {
          return _shell(
            Center(child: Text('Waiting for ${match.names[1]} to accept.')),
          );
        }
        if (match.status == OnlineMatchStatus.finished) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => unawaited(_handleFinished(match)),
          );
        }
        return _board(context, match);
      },
    );
  }

  Widget _shell(Widget body, {String title = 'Online game'}) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SafeArea(child: body),
  );

  Widget _board(BuildContext context, OnlineMatch match) {
    final theme = Theme.of(context);
    final game = match.game();
    final seat = game.currentPlayer.clamp(0, 1);
    final mine = match.isMyTurn(widget.user.uid);
    final color = SeatPalette.color(seat);
    final canRoll = mine && !_busy && game.rollsRemaining > 0 && !game.isOver;
    final canAct = mine && game.hasRolledThisRound && !game.isOver;
    final opponent = match.names[1 - (match.seatOf(widget.user.uid) ?? 0)];

    return Scaffold(
      appBar: AppBar(
        title: Text('vs $opponent'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Round ${game.round.clamp(1, game.roundCount)} / ${game.roundCount}',
                style: theme.textTheme.labelLarge,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          TurnHeader(
            name: mine ? 'Your turn' : "${match.names[seat]}'s turn",
            color: color,
            rollsRemaining: game.rollsRemaining,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: ScoreTable(
                cards: game.scoreCards,
                currentPlayer: seat,
                currentDice: game.dice,
                canCommit: canAct && !_busy,
                onCommit: (ScoreCategory c) {
                  AppHaptics.commit();
                  _act(match, (g) => g.commitScore(c));
                },
                names: match.names,
              ),
            ),
          ),
          ControlDeck(
            dice: game.dice,
            held: game.held,
            canHold: canAct && !_busy,
            placeholder: !game.hasRolledThisRound,
            rollCount: game.round * 100 + seat * 10 + (3 - game.rollsRemaining),
            seatColor: color,
            rollsRemaining: game.rollsRemaining,
            canRoll: canRoll,
            awaitingCommit: mine && !canRoll && canAct,
            onRoll: () {
              AppHaptics.roll();
              _act(match, (g) => g.roll());
            },
            onToggleHold: (i) {
              AppHaptics.hold();
              _act(match, (g) => g.toggleHold(i));
            },
          ),
        ],
      ),
    );
  }
}
