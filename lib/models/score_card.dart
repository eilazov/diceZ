/// Pure scoring logic for Dice Zee. No Flutter dependencies.
library;

import 'game_mode.dart';
import 'score_category.dart';

export 'score_category.dart';

/// Holds the committed score for each category and computes category scores.
class ScoreCard {
  ScoreCard({this.mode = GameMode.extended});

  final GameMode mode;
  final Map<ScoreCategory, int> _committed = {};

  static const List<ScoreCategory> _upper = [
    ScoreCategory.ones,
    ScoreCategory.twos,
    ScoreCategory.threes,
    ScoreCategory.fours,
    ScoreCategory.fives,
    ScoreCategory.sixes,
  ];

  /// Whether [category] has already been scored this game.
  bool isFilled(ScoreCategory category) => _committed.containsKey(category);

  /// The committed score for [category], or null if it is still open.
  int? scoreOf(ScoreCategory category) => _committed[category];

  /// Sum of ones through sixes committed so far.
  int get upperSum => _upper.fold(0, (sum, c) => sum + (_committed[c] ?? 0));

  /// The upper-section bonus: [GameMode.upperBonusValue] once [upperSum]
  /// reaches [GameMode.upperBonusThreshold] in a mode that has one.
  int get upperBonus =>
      mode.hasUpperBonus && upperSum >= GameMode.upperBonusThreshold
      ? GameMode.upperBonusValue
      : 0;

  /// Every committed category plus the upper bonus.
  int get total => _committed.values.fold(0, (a, b) => a + b) + upperBonus;

  /// Whether every category on this mode's sheet has been committed.
  bool get isComplete => mode.categories.every(isFilled);

  /// What [dice] would score in [category] on this card right now. In
  /// standard mode a Dice Zee rolled after the Dice Zee box is filled (even
  /// with 0) is worth 50 in any open category.
  int potentialScore(ScoreCategory category, List<int> dice) {
    if (mode == GameMode.standard &&
        isFilled(ScoreCategory.yahtzee) &&
        _facesWithAtLeast(dice, 5).isNotEmpty) {
      return 50;
    }
    return score(category, dice, mode: mode);
  }

  /// Score [dice] for [category] and lock it in. Throws [StateError] if the
  /// category was already committed, [ArgumentError] if it is not on this
  /// mode's sheet.
  void commit(ScoreCategory category, List<int> dice) {
    if (!mode.categories.contains(category)) {
      throw ArgumentError('$category is not on the ${mode.name} sheet');
    }
    if (isFilled(category)) {
      throw StateError('$category is already scored');
    }
    _committed[category] = potentialScore(category, dice);
  }

  /// Score [dice] (five values in 1..6) for [category]. Pure; does not mutate.
  static int score(
    ScoreCategory category,
    List<int> dice, {
    GameMode mode = GameMode.extended,
  }) {
    final standard = mode == GameMode.standard;
    switch (category) {
      case ScoreCategory.ones:
        return _faceTotal(dice, 1);
      case ScoreCategory.twos:
        return _faceTotal(dice, 2);
      case ScoreCategory.threes:
        return _faceTotal(dice, 3);
      case ScoreCategory.fours:
        return _faceTotal(dice, 4);
      case ScoreCategory.fives:
        return _faceTotal(dice, 5);
      case ScoreCategory.sixes:
        return _faceTotal(dice, 6);
      case ScoreCategory.onePair:
        final faces = _facesWithAtLeast(dice, 2);
        return faces.isEmpty ? 0 : faces.last * 2;
      case ScoreCategory.twoPairs:
        final faces = _facesWithAtLeast(dice, 2);
        return faces.length < 2
            ? 0
            : (faces[faces.length - 1] + faces[faces.length - 2]) * 2;
      case ScoreCategory.threeOfAKind:
        return _facesWithAtLeast(dice, 3).isEmpty ? 0 : _sum(dice);
      case ScoreCategory.fourOfAKind:
        return _facesWithAtLeast(dice, 4).isEmpty ? 0 : _sum(dice);
      case ScoreCategory.yahtzee:
        return _facesWithAtLeast(dice, 5).isEmpty ? 0 : (standard ? 50 : 100);
      case ScoreCategory.chance:
        return _sum(dice);
      case ScoreCategory.fullHouse:
        final pairs = _facesWithAtLeast(dice, 2);
        final triples = _facesWithAtLeast(dice, 3);
        final hasFive = _facesWithAtLeast(dice, 5).isNotEmpty;
        return (!hasFive && triples.length == 1 && pairs.length == 2)
            ? (standard ? 25 : 30)
            : 0;
      case ScoreCategory.smallStraight:
        return _containsRun(dice, 4) ? (standard ? 30 : 40) : 0;
      case ScoreCategory.largeStraight:
        return _containsRun(dice, 5) ? (standard ? 40 : 50) : 0;
    }
  }

  static int _sum(List<int> dice) => dice.fold(0, (a, b) => a + b);

  /// Whether [dice] contains [length] consecutive distinct values.
  static bool _containsRun(List<int> dice, int length) {
    final present = dice.toSet();
    for (var start = 1; start + length - 1 <= 6; start++) {
      if (List.generate(length, (i) => start + i).every(present.contains)) {
        return true;
      }
    }
    return false;
  }

  /// Sum of every die in [dice] whose value equals [face].
  static int _faceTotal(List<int> dice, int face) =>
      dice.where((d) => d == face).length * face;

  /// Faces (ascending) that appear at least [min] times in [dice].
  static List<int> _facesWithAtLeast(List<int> dice, int min) {
    final counts = <int, int>{};
    for (final d in dice) {
      counts[d] = (counts[d] ?? 0) + 1;
    }
    final faces =
        counts.entries.where((e) => e.value >= min).map((e) => e.key).toList()
          ..sort();
    return faces;
  }
}
