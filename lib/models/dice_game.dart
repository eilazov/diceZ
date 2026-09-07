import 'dart:math';

import 'score_card.dart';

/// Dice per roll.
const int _diceCount = 5;

/// Rolls allowed at the start of each round.
const int _rollsPerRound = 3;

/// One solo game: 15 rounds, up to 3 rolls of 5 dice per round with holds.
///
/// Pure Dart, no Flutter. The RNG is injectable so tests are deterministic.
class DiceGame {
  DiceGame({Random? random}) : _random = random ?? Random();

  final Random _random;
  final ScoreCard scoreCard = ScoreCard();

  int _round = 1;
  int _rollsRemaining = _rollsPerRound;
  bool _hasRolledThisRound = false;
  final List<int> _dice = List<int>.filled(_diceCount, 1);
  final List<bool> _held = List<bool>.filled(_diceCount, false);

  /// Current round, 1.._roundCount while playing; _roundCount + 1 once complete.
  int get round => _round;

  /// Rolls left in the current round (0.._rollsPerRound).
  int get rollsRemaining => _rollsRemaining;

  /// Whether the player has rolled at least once this round.
  bool get hasRolledThisRound => _hasRolledThisRound;

  /// The five current dice values. Unmodifiable.
  List<int> get dice => List.unmodifiable(_dice);

  /// Hold state per die. Unmodifiable.
  List<bool> get held => List.unmodifiable(_held);

  /// Whether every category has been scored.
  bool get isOver => scoreCard.isComplete;

  /// Re-roll every die that is not held and spend one roll.
  void roll() {
    if (_rollsRemaining <= 0) {
      throw StateError('no rolls remaining this round');
    }
    for (var i = 0; i < _diceCount; i++) {
      if (!_held[i]) {
        _dice[i] = _random.nextInt(6) + 1;
      }
    }
    _rollsRemaining--;
    _hasRolledThisRound = true;
  }

  /// Toggle whether die [index] is kept on the next roll. Only allowed after
  /// the first roll of the round.
  void toggleHold(int index) {
    if (!_hasRolledThisRound) {
      throw StateError('cannot hold before rolling');
    }
    _held[index] = !_held[index];
  }

  /// Score the current dice in [category], then advance to the next round.
  void commitScore(ScoreCategory category) {
    if (!_hasRolledThisRound) {
      throw StateError('cannot score before rolling');
    }
    scoreCard.commit(category, _dice);
    _round++;
    _rollsRemaining = _rollsPerRound;
    _hasRolledThisRound = false;
    _held.fillRange(0, _diceCount, false);
  }
}
