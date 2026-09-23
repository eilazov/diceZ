import 'package:flutter_test/flutter_test.dart';
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
}
