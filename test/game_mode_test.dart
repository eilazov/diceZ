import 'package:flutter_test/flutter_test.dart';

import 'package:dice_zee/models/game_mode.dart';
import 'package:dice_zee/models/score_card.dart';

void main() {
  test('extended keeps all 15 categories and no upper bonus', () {
    expect(GameMode.extended.categories, ScoreCategory.values);
    expect(GameMode.extended.rounds, 15);
    expect(GameMode.extended.hasUpperBonus, isFalse);
  });

  test('standard drops one pair and two pairs: 13 rounds, upper bonus', () {
    final categories = GameMode.standard.categories;
    expect(categories, hasLength(13));
    expect(categories, isNot(contains(ScoreCategory.onePair)));
    expect(categories, isNot(contains(ScoreCategory.twoPairs)));
    expect(GameMode.standard.rounds, 13);
    expect(GameMode.standard.hasUpperBonus, isTrue);
  });

  test('categories stay in sheet order', () {
    for (final mode in GameMode.values) {
      final indexes = [for (final c in mode.categories) c.index];
      expect(indexes, [...indexes]..sort());
    }
  });

  test('fromName resolves names and defaults to extended', () {
    expect(GameMode.fromName('standard'), GameMode.standard);
    expect(GameMode.fromName('extended'), GameMode.extended);
    expect(GameMode.fromName(null), GameMode.extended);
    expect(GameMode.fromName('nonsense'), GameMode.extended);
  });
}
