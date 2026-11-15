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
import 'dice_zee_celebration.dart';
import 'game_controls.dart';
import 'online_results_screen.dart';
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

  /// A save is in flight. Only guards against overlapping writes; it is not
  /// rendered, so controls don't flicker while a move is being acknowledged.
  bool _busy = false;

  /// Identifies the roll the board last showed, so a snapshot is celebrated
  /// once however often it is delivered. Null until the first snapshot, which
  /// is only a baseline: a Dice Zee already on the table at open is stale.
  String? _seenRoll;
  _Show? _show;

  /// Notes the roll in [match] and starts the Dice Zee show if it is a new one.
  /// Runs for both players, since both receive every snapshot.
  void _noteRoll(OnlineMatch match) {
    final game = match.game();
    final roll =
        '${game.round}/${game.currentPlayer}/${game.rollsRemaining}/'
        '${game.hasRolledThisRound}';
    if (roll == _seenRoll) return;
    final first = _seenRoll == null;
    _seenRoll = roll;
    if (first) return;

    if (game.isDiceZee) {
      AppHaptics.diceZee();
      setState(
        () => _show = _Show(
          roll: roll,
          face: game.dice.first,
          seat: game.currentPlayer,
          name: match.isMyTurn(widget.user.uid)
              ? 'You'
              : match.names[game.currentPlayer],
          points: ScoreCard.score(
            ScoreCategory.yahtzee,
            game.dice,
            mode: match.mode,
          ),
        ),
      );
    } else if (_show != null) {
      setState(() => _show = null);
    }
  }

  /// [exclusive] actions (roll, commit) are dropped while another save is in
  /// flight. Hold toggles are not: each tap builds on the newest snapshot, so
  /// quick taps on two dice both count.
  Future<void> _act(
    OnlineMatch match,
    void Function(DiceGame game) apply, {
    bool exclusive = true,
  }) async {
    if (exclusive && _busy) return;
    _busy = true;
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
      _busy = false;
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
    final next = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => OnlineResultsScreen(
          match: match,
          uid: widget.user.uid,
          service: _service,
        ),
      ),
    );
    if (!mounted) return;
    if (next is String) {
      // Both players asked for a rematch: continue straight into it.
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OnlineGameScreen(
            user: widget.user,
            matchId: next,
            service: widget.service,
            storage: widget.storage,
            playerStorage: widget.playerStorage,
            random: widget.random,
          ),
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _noteRoll(match);
        });
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
    final canRoll = mine && game.rollsRemaining > 0 && !game.isOver;
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          Column(
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
                    canCommit: canAct,
                    onCommit: (ScoreCategory c) {
                      if (_busy) return;
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
                canHold: canAct,
                placeholder: !game.hasRolledThisRound,
                rollCount:
                    game.round * 100 + seat * 10 + (3 - game.rollsRemaining),
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
                  _act(match, (g) => g.toggleHold(i), exclusive: false);
                },
              ),
            ],
          ),
          if (_show case final show?)
            DiceZeeCelebration(
              key: ValueKey(show.roll),
              face: show.face,
              accent: SeatPalette.color(show.seat),
              name: show.name,
              points: show.points,
              onDone: () => setState(() => _show = null),
            ),
        ],
      ),
    );
  }
}

/// What the Dice Zee show needs, captured when the roll arrives because the
/// match moves on (and the dice reset) before the show ends.
class _Show {
  const _Show({
    required this.roll,
    required this.face,
    required this.seat,
    required this.name,
    required this.points,
  });

  final String roll;
  final int face;
  final int seat;
  final String name;
  final int points;
}
