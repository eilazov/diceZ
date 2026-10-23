import 'package:flutter_test/flutter_test.dart';
import 'package:dice_zee/models/game_mode.dart';
import 'package:dice_zee/models/score_card.dart';

void main() {
  group('upper section', () {
    test('ones sums only the dice showing 1', () {
      expect(ScoreCard.score(ScoreCategory.ones, [1, 1, 3, 1, 6]), 3);
    });

    test('ones is 0 when no die shows 1', () {
      expect(ScoreCard.score(ScoreCategory.ones, [2, 3, 4, 5, 6]), 0);
    });

    test('twos sums only the dice showing 2', () {
      expect(ScoreCard.score(ScoreCategory.twos, [2, 2, 2, 4, 5]), 6);
    });

    test('threes sums only the dice showing 3', () {
      expect(ScoreCard.score(ScoreCategory.threes, [3, 3, 1, 1, 1]), 6);
    });

    test('fours sums only the dice showing 4', () {
      expect(ScoreCard.score(ScoreCategory.fours, [4, 4, 4, 4, 2]), 16);
    });

    test('fives sums only the dice showing 5', () {
      expect(ScoreCard.score(ScoreCategory.fives, [5, 1, 5, 2, 3]), 10);
    });

    test('sixes sums only the dice showing 6', () {
      expect(ScoreCard.score(ScoreCategory.sixes, [6, 6, 6, 6, 6]), 30);
    });
  });

  group('onePair', () {
    test('scores twice the highest paired face', () {
      expect(ScoreCard.score(ScoreCategory.onePair, [3, 3, 5, 5, 1]), 10);
    });

    test('a triple still counts as a pair', () {
      expect(ScoreCard.score(ScoreCategory.onePair, [6, 6, 6, 2, 1]), 12);
    });

    test('is 0 when no face repeats', () {
      expect(ScoreCard.score(ScoreCategory.onePair, [1, 2, 3, 4, 5]), 0);
    });
  });

  group('twoPairs', () {
    test('sums the four dice of two distinct pairs', () {
      expect(ScoreCard.score(ScoreCategory.twoPairs, [3, 3, 5, 5, 1]), 16);
    });

    test('a triple supplies one of the two pairs', () {
      expect(ScoreCard.score(ScoreCategory.twoPairs, [5, 5, 5, 2, 2]), 14);
    });

    test('is 0 with only one distinct pair', () {
      expect(ScoreCard.score(ScoreCategory.twoPairs, [4, 4, 1, 2, 3]), 0);
    });

    test('is 0 for four of a kind alone', () {
      expect(ScoreCard.score(ScoreCategory.twoPairs, [4, 4, 4, 4, 1]), 0);
    });
  });

  group('threeOfAKind', () {
    test('scores the sum of all five dice when a face appears three times', () {
      expect(ScoreCard.score(ScoreCategory.threeOfAKind, [2, 2, 2, 4, 5]), 15);
    });

    test('a four-of-a-kind also satisfies it', () {
      expect(ScoreCard.score(ScoreCategory.threeOfAKind, [3, 3, 3, 3, 1]), 13);
    });

    test('is 0 without three matching dice', () {
      expect(ScoreCard.score(ScoreCategory.threeOfAKind, [2, 2, 4, 4, 5]), 0);
    });
  });

  group('fourOfAKind', () {
    test('scores the sum of all five dice when a face appears four times', () {
      expect(ScoreCard.score(ScoreCategory.fourOfAKind, [5, 5, 5, 5, 2]), 22);
    });

    test('is 0 with only three matching dice', () {
      expect(ScoreCard.score(ScoreCategory.fourOfAKind, [5, 5, 5, 2, 2]), 0);
    });
  });

  group('yahtzee', () {
    test('scores 100 when all five dice match', () {
      expect(ScoreCard.score(ScoreCategory.yahtzee, [4, 4, 4, 4, 4]), 100);
    });

    test('is 0 when one die differs', () {
      expect(ScoreCard.score(ScoreCategory.yahtzee, [4, 4, 4, 4, 3]), 0);
    });
  });

  group('chance', () {
    test('sums all five dice', () {
      expect(ScoreCard.score(ScoreCategory.chance, [1, 3, 4, 5, 6]), 19);
    });
  });

  group('fullHouse', () {
    test('scores 30 for three of one face plus two of another', () {
      expect(ScoreCard.score(ScoreCategory.fullHouse, [2, 2, 2, 5, 5]), 30);
    });

    test('is 0 for five of a kind', () {
      expect(ScoreCard.score(ScoreCategory.fullHouse, [3, 3, 3, 3, 3]), 0);
    });

    test('is 0 for four of a kind plus a single', () {
      expect(ScoreCard.score(ScoreCategory.fullHouse, [3, 3, 3, 3, 5]), 0);
    });

    test('is 0 for two pairs and a single', () {
      expect(ScoreCard.score(ScoreCategory.fullHouse, [3, 3, 5, 5, 1]), 0);
    });
  });

  group('smallStraight', () {
    test('scores 40 for 1-2-3-4 present', () {
      expect(ScoreCard.score(ScoreCategory.smallStraight, [1, 2, 3, 4, 4]), 40);
    });

    test('scores 40 for 3-4-5-6 present', () {
      expect(ScoreCard.score(ScoreCategory.smallStraight, [3, 4, 5, 6, 6]), 40);
    });

    test('a large straight also contains a small straight', () {
      expect(ScoreCard.score(ScoreCategory.smallStraight, [2, 3, 4, 5, 6]), 40);
    });

    test('is 0 without four consecutive values', () {
      expect(ScoreCard.score(ScoreCategory.smallStraight, [1, 2, 3, 5, 6]), 0);
    });
  });

  group('largeStraight', () {
    test('scores 50 for 1-2-3-4-5', () {
      expect(ScoreCard.score(ScoreCategory.largeStraight, [1, 2, 3, 4, 5]), 50);
    });

    test('scores 50 for 2-3-4-5-6', () {
      expect(ScoreCard.score(ScoreCategory.largeStraight, [6, 5, 4, 3, 2]), 50);
    });

    test('is 0 for a small straight only', () {
      expect(ScoreCard.score(ScoreCategory.largeStraight, [1, 2, 3, 4, 4]), 0);
    });
  });

  group('ScoreCard instance', () {
    test('starts with nothing filled and a zero total', () {
      final card = ScoreCard();
      expect(card.isComplete, isFalse);
      expect(card.total, 0);
      expect(card.scoreOf(ScoreCategory.chance), isNull);
      expect(card.isFilled(ScoreCategory.chance), isFalse);
    });

    test('commit stores the computed score and adds to the total', () {
      final card = ScoreCard();
      card.commit(ScoreCategory.threes, [3, 3, 3, 1, 2]);
      expect(card.isFilled(ScoreCategory.threes), isTrue);
      expect(card.scoreOf(ScoreCategory.threes), 9);
      expect(card.total, 9);
    });

    test('committing a zero-scoring category still fills it', () {
      final card = ScoreCard();
      card.commit(ScoreCategory.yahtzee, [1, 2, 3, 4, 5]);
      expect(card.isFilled(ScoreCategory.yahtzee), isTrue);
      expect(card.scoreOf(ScoreCategory.yahtzee), 0);
    });

    test('re-committing a filled category throws', () {
      final card = ScoreCard();
      card.commit(ScoreCategory.chance, [1, 1, 1, 1, 1]);
      expect(
        () => card.commit(ScoreCategory.chance, [6, 6, 6, 6, 6]),
        throwsA(isA<StateError>()),
      );
    });

    test('isComplete once all 15 categories are filled', () {
      final card = ScoreCard();
      for (final category in ScoreCategory.values) {
        card.commit(category, [1, 2, 3, 4, 5]);
      }
      expect(card.isComplete, isTrue);
    });
  });

  group('standard mode scoring', () {
    int std(ScoreCategory c, List<int> dice) =>
        ScoreCard.score(c, dice, mode: GameMode.standard);

    test('Dice Zee is worth 50', () {
      expect(std(ScoreCategory.yahtzee, [3, 3, 3, 3, 3]), 50);
      expect(std(ScoreCategory.yahtzee, [3, 3, 3, 3, 4]), 0);
    });

    test('full house 25, small straight 30, large straight 40', () {
      expect(std(ScoreCategory.fullHouse, [2, 2, 3, 3, 3]), 25);
      expect(std(ScoreCategory.smallStraight, [1, 2, 3, 4, 6]), 30);
      expect(std(ScoreCategory.largeStraight, [2, 3, 4, 5, 6]), 40);
    });

    test('extended values are unchanged', () {
      expect(ScoreCard.score(ScoreCategory.yahtzee, [3, 3, 3, 3, 3]), 100);
      expect(ScoreCard.score(ScoreCategory.fullHouse, [2, 2, 3, 3, 3]), 30);
    });
  });

  group('standard mode card', () {
    ScoreCard card() => ScoreCard(mode: GameMode.standard);

    test('rejects categories that are not on the standard sheet', () {
      expect(
        () => card().commit(ScoreCategory.onePair, [1, 1, 2, 3, 4]),
        throwsArgumentError,
      );
    });

    test('is complete after the 13 standard categories', () {
      final c = card();
      for (final category in GameMode.standard.categories) {
        expect(c.isComplete, isFalse);
        c.commit(category, [1, 2, 3, 4, 6]);
      }
      expect(c.isComplete, isTrue);
    });

    test('upper section at 63 or more earns a 35 bonus in the total', () {
      final c = card();
      c.commit(ScoreCategory.ones, [1, 1, 1, 5, 6]); // 3
      c.commit(ScoreCategory.twos, [2, 2, 2, 5, 6]); // 6
      c.commit(ScoreCategory.threes, [3, 3, 3, 5, 6]); // 9
      c.commit(ScoreCategory.fours, [4, 4, 4, 5, 6]); // 12
      c.commit(ScoreCategory.fives, [5, 5, 5, 1, 6]); // 15
      expect(c.upperBonus, 0);
      c.commit(ScoreCategory.sixes, [6, 6, 6, 1, 2]); // 18 -> 63
      expect(c.upperSum, 63);
      expect(c.upperBonus, 35);
      expect(c.total, 63 + 35);
    });

    test('62 earns no bonus', () {
      final c = card();
      c.commit(ScoreCategory.ones, [1, 1, 1, 5, 6]); // 3
      c.commit(ScoreCategory.twos, [2, 2, 2, 5, 6]); // 6
      c.commit(ScoreCategory.threes, [3, 3, 3, 5, 6]); // 9
      c.commit(ScoreCategory.fours, [4, 4, 4, 5, 6]); // 12
      c.commit(ScoreCategory.fives, [5, 5, 5, 1, 6]); // 15
      c.commit(ScoreCategory.sixes, [6, 6, 1, 1, 2]); // 12 -> 57
      expect(c.upperBonus, 0);
      expect(c.total, 57);
    });

    test('extended cards never get the bonus', () {
      final c = ScoreCard();
      for (final category in [
        ScoreCategory.sixes,
        ScoreCategory.fives,
        ScoreCategory.fours,
        ScoreCategory.threes,
        ScoreCategory.twos,
        ScoreCategory.ones,
      ]) {
        c.commit(category, [1, 2, 3, 4, 5]);
      }
      expect(c.upperBonus, 0);
    });

    test('a Dice Zee after the Dice Zee box is filled scores 50 anywhere', () {
      final c = card();
      c.commit(ScoreCategory.yahtzee, [2, 2, 2, 2, 2]);
      expect(c.potentialScore(ScoreCategory.chance, [4, 4, 4, 4, 4]), 50);
      expect(c.potentialScore(ScoreCategory.sixes, [6, 6, 6, 6, 6]), 50);
      expect(c.potentialScore(ScoreCategory.fullHouse, [4, 4, 4, 4, 4]), 50);

      c.commit(ScoreCategory.smallStraight, [5, 5, 5, 5, 5]);
      expect(c.scoreOf(ScoreCategory.smallStraight), 50);
    });

    test('a scratched (0) Dice Zee box still enables the 50 rule', () {
      final c = card();
      c.commit(ScoreCategory.yahtzee, [1, 2, 3, 4, 6]);
      expect(c.potentialScore(ScoreCategory.chance, [4, 4, 4, 4, 4]), 50);
    });

    test('without a filled Dice Zee box dice score normally', () {
      final c = card();
      expect(c.potentialScore(ScoreCategory.chance, [4, 4, 4, 4, 4]), 20);
      expect(c.potentialScore(ScoreCategory.yahtzee, [4, 4, 4, 4, 4]), 50);
    });

    test('non-Dice-Zee dice score normally even when the box is filled', () {
      final c = card();
      c.commit(ScoreCategory.yahtzee, [2, 2, 2, 2, 2]);
      expect(c.potentialScore(ScoreCategory.chance, [1, 2, 3, 4, 5]), 15);
    });

    test('extended mode has no joker rule', () {
      final c = ScoreCard();
      c.commit(ScoreCategory.yahtzee, [2, 2, 2, 2, 2]);
      expect(c.potentialScore(ScoreCategory.chance, [4, 4, 4, 4, 4]), 20);
    });
  });
}
