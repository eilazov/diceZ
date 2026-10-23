import 'score_category.dart';

/// Which rule set a match is played under. Persisted by [name].
enum GameMode {
  /// Classic sheet: 13 categories, upper-section bonus, no pairs, and a
  /// Dice Zee after the Dice Zee box is filled is worth 50 in any open box.
  standard,

  /// The original 15-category sheet (pairs, big Dice Zee, no bonus).
  extended;

  /// Upper-section total needed for the bonus (standard mode).
  static const int upperBonusThreshold = 63;
  static const int upperBonusValue = 35;

  /// The categories on this mode's sheet, in sheet order.
  List<ScoreCategory> get categories => switch (this) {
    GameMode.extended => ScoreCategory.values,
    GameMode.standard => [
      for (final c in ScoreCategory.values)
        if (c != ScoreCategory.onePair && c != ScoreCategory.twoPairs) c,
    ],
  };

  /// Rounds per match: one per category.
  int get rounds => categories.length;

  bool get hasUpperBonus => this == GameMode.standard;

  String get label => switch (this) {
    GameMode.standard => 'Standard',
    GameMode.extended => 'Extended',
  };

  /// Resolve a stored [name]; anything unknown (or absent, for matches saved
  /// before modes existed) is [extended].
  static GameMode fromName(String? name) => GameMode.values.firstWhere(
    (m) => m.name == name,
    orElse: () => GameMode.extended,
  );
}
