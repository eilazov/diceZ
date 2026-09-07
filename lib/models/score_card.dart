/// Pure scoring logic for Dice Zee. No Flutter dependencies.
library;

/// The 15 categories on a Dice Zee score sheet, in sheet order.
enum ScoreCategory {
  ones,
  twos,
  threes,
  fours,
  fives,
  sixes,
  onePair,
  twoPairs,
  threeOfAKind,
  fourOfAKind,
  fullHouse,
  smallStraight,
  largeStraight,
  yahtzee,
  chance,
}

/// Holds the committed score for each category and computes category scores.
class ScoreCard {
  final Map<ScoreCategory, int> _committed = {};

  /// Whether [category] has already been scored this game.
  bool isFilled(ScoreCategory category) => _committed.containsKey(category);

  /// The committed score for [category], or null if it is still open.
  int? scoreOf(ScoreCategory category) => _committed[category];

  /// Sum of every committed category.
  int get total => _committed.values.fold(0, (a, b) => a + b);

  /// Whether all 15 categories have been committed.
  bool get isComplete => _committed.length == ScoreCategory.values.length;

  /// Score [dice] for [category] and lock it in. Throws [StateError] if the
  /// category was already committed.
  void commit(ScoreCategory category, List<int> dice) {
    if (isFilled(category)) {
      throw StateError('$category is already scored');
    }
    _committed[category] = score(category, dice);
  }

  /// Score [dice] (five values in 1..6) for [category]. Pure; does not mutate.
  static int score(ScoreCategory category, List<int> dice) {
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
        return faces.length < 2 ? 0 : (faces[faces.length - 1] + faces[faces.length - 2]) * 2;
      case ScoreCategory.threeOfAKind:
        return _facesWithAtLeast(dice, 3).isEmpty ? 0 : _sum(dice);
      case ScoreCategory.fourOfAKind:
        return _facesWithAtLeast(dice, 4).isEmpty ? 0 : _sum(dice);
      case ScoreCategory.yahtzee:
        return _facesWithAtLeast(dice, 5).isEmpty ? 0 : 100;
      case ScoreCategory.chance:
        return _sum(dice);
      case ScoreCategory.fullHouse:
        final pairs = _facesWithAtLeast(dice, 2);
        final triples = _facesWithAtLeast(dice, 3);
        final hasFive = _facesWithAtLeast(dice, 5).isNotEmpty;
        return (!hasFive && triples.length == 1 && pairs.length == 2) ? 25 : 0;
      case ScoreCategory.smallStraight:
        return _containsRun(dice, 4) ? 30 : 0;
      case ScoreCategory.largeStraight:
        return _containsRun(dice, 5) ? 40 : 0;
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
    final faces = counts.entries.where((e) => e.value >= min).map((e) => e.key).toList()
      ..sort();
    return faces;
  }
}
