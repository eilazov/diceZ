import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:dice_zee/models/dice_game.dart';
import 'package:dice_zee/models/score_card.dart';

void main() {
  group('new game', () {
    test('starts on round 1 with 3 rolls and nothing held', () {
      final game = DiceGame(random: Random(1));
      expect(game.round, 1);
      expect(game.rollsRemaining, 3);
      expect(game.hasRolledThisRound, isFalse);
      expect(game.held, everyElement(isFalse));
      expect(game.held.length, 5);
      expect(game.isOver, isFalse);
    });
  });

  group('roll', () {
    test('first roll spends a roll and marks the round as rolled', () {
      final game = DiceGame(random: Random(1));
      game.roll();
      expect(game.rollsRemaining, 2);
      expect(game.hasRolledThisRound, isTrue);
    });

    test('produces five dice each in 1..6', () {
      final game = DiceGame(random: Random(1));
      game.roll();
      expect(game.dice.length, 5);
      expect(game.dice, everyElement(inInclusiveRange(1, 6)));
    });

    test('uses the injected RNG so a fixed seed is reproducible', () {
      final a = DiceGame(random: Random(42))..roll();
      final b = DiceGame(random: Random(42))..roll();
      expect(a.dice, b.dice);
    });

    test('three rolls exhaust the round', () {
      final game = DiceGame(random: Random(1));
      game.roll();
      game.roll();
      game.roll();
      expect(game.rollsRemaining, 0);
    });

    test('rolling with no rolls left throws', () {
      final game = DiceGame(random: Random(1));
      game.roll();
      game.roll();
      game.roll();
      expect(game.roll, throwsA(isA<StateError>()));
    });
  });

  group('hold', () {
    test('cannot hold before the first roll of the round', () {
      final game = DiceGame(random: Random(1));
      expect(() => game.toggleHold(0), throwsA(isA<StateError>()));
    });

    test('toggleHold flips a die and back', () {
      final game = DiceGame(random: Random(1))..roll();
      game.toggleHold(2);
      expect(game.held[2], isTrue);
      game.toggleHold(2);
      expect(game.held[2], isFalse);
    });

    test('held dice keep their values across a roll', () {
      final game = DiceGame(random: Random(7))..roll();
      for (var i = 0; i < 5; i++) {
        game.toggleHold(i);
      }
      final before = [...game.dice];
      game.roll();
      expect(game.dice, before);
    });
  });

  group('commitScore', () {
    test('records the score and starts the next round fresh', () {
      final game = DiceGame(random: Random(1))..roll();
      game.commitScore(ScoreCategory.chance);

      expect(game.scoreCard.isFilled(ScoreCategory.chance), isTrue);
      expect(game.round, 2);
      expect(game.rollsRemaining, 3);
      expect(game.hasRolledThisRound, isFalse);
      expect(game.held, everyElement(isFalse));
    });

    test('cannot commit before rolling', () {
      final game = DiceGame(random: Random(1));
      expect(
        () => game.commitScore(ScoreCategory.chance),
        throwsA(isA<StateError>()),
      );
    });

    test('is over once all 15 categories are committed', () {
      final game = DiceGame(random: Random(1));
      for (final category in ScoreCategory.values) {
        game.roll();
        game.commitScore(category);
      }
      expect(game.isOver, isTrue);
      expect(game.round, 16);
    });
  });
}
