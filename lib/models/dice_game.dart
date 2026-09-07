import 'dart:math';

import 'score_card.dart';

/// Dice per roll.
const int _diceCount = 5;

/// Rolls allowed at the start of each turn.
const int _rollsPerTurn = 3;

/// A 2–4 player hot-seat match: 15 rounds, each player taking a turn of up to
/// 3 rolls of 5 dice with holds before committing to one of their categories.
///
/// Pure Dart, no Flutter. The RNG is injectable so tests are deterministic.
class DiceGame {
  DiceGame({required this.playerCount, Random? random})
      : assert(playerCount >= 2 && playerCount <= 4),
        _random = random ?? Random(),
        _cards = List.generate(playerCount, (_) => ScoreCard());

  final int playerCount;
  final Random _random;
  final List<ScoreCard> _cards;

  int _round = 1;
  int _currentPlayer = 0;
  int _rollsRemaining = _rollsPerTurn;
  bool _hasRolled = false;
  final List<int> _dice = List<int>.filled(_diceCount, 1);
  final List<bool> _held = List<bool>.filled(_diceCount, false);

  /// Current round, 1.._roundCount while playing; _roundCount + 1 once complete.
  int get round => _round;

  /// Seat whose turn it is, 0-based.
  int get currentPlayer => _currentPlayer;

  /// Rolls left in the current turn (0.._rollsPerTurn).
  int get rollsRemaining => _rollsRemaining;

  /// Whether the active player has rolled at least once this turn.
  bool get hasRolledThisRound => _hasRolled;

  /// The five current dice values. Unmodifiable.
  List<int> get dice => List.unmodifiable(_dice);

  /// Hold state per die. Unmodifiable.
  List<bool> get held => List.unmodifiable(_held);

  /// The score card belonging to [player].
  ScoreCard scoreCardFor(int player) => _cards[player];

  /// [player]'s current total.
  int totalFor(int player) => _cards[player].total;

  /// Every player's total, indexed by seat.
  List<int> get standings =>
      List.generate(playerCount, (p) => _cards[p].total);

  /// Whether every player has scored all categories.
  bool get isOver => _cards.every((c) => c.isComplete);

  /// The seat with the strictly-highest total, or null if the game is not over
  /// or the top total is shared.
  int? get winner {
    if (!isOver) return null;
    final totals = standings;
    final best = totals.reduce(max);
    final leaders = [
      for (var p = 0; p < playerCount; p++)
        if (totals[p] == best) p,
    ];
    return leaders.length == 1 ? leaders.first : null;
  }

  /// Re-roll every die that is not held and spend one roll.
  void roll() {
    if (_rollsRemaining <= 0) {
      throw StateError('no rolls remaining this turn');
    }
    for (var i = 0; i < _diceCount; i++) {
      if (!_held[i]) {
        _dice[i] = _random.nextInt(6) + 1;
      }
    }
    _rollsRemaining--;
    _hasRolled = true;
  }

  /// Toggle whether die [index] is kept on the next roll. Only allowed after
  /// the first roll of the turn.
  void toggleHold(int index) {
    if (!_hasRolled) {
      throw StateError('cannot hold before rolling');
    }
    _held[index] = !_held[index];
  }

  /// Score the current dice in [category] for the active player, then pass the
  /// turn (and advance the round when it wraps back to seat 0).
  void commitScore(ScoreCategory category) {
    if (!_hasRolled) {
      throw StateError('cannot score before rolling');
    }
    _cards[_currentPlayer].commit(category, _dice);

    _currentPlayer = (_currentPlayer + 1) % playerCount;
    if (_currentPlayer == 0) _round++;

    _rollsRemaining = _rollsPerTurn;
    _hasRolled = false;
    _held.fillRange(0, _diceCount, false);
    _dice.fillRange(0, _diceCount, 1);
  }
}
