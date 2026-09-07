import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:dice_zee/models/dice_game.dart';
import 'package:dice_zee/models/score_card.dart';

/// Play one full turn for the current player: roll once, then commit [category].
void playTurn(DiceGame game, ScoreCategory category) {
  game.roll();
  game.commitScore(category);
}

void main() {
  group('construction', () {
    test('accepts 2 to 4 players', () {
      expect(DiceGame(playerCount: 2).playerCount, 2);
      expect(DiceGame(playerCount: 4).playerCount, 4);
    });

    test('rejects fewer than 2 or more than 4 players', () {
      expect(() => DiceGame(playerCount: 1), throwsA(isA<AssertionError>()));
      expect(() => DiceGame(playerCount: 5), throwsA(isA<AssertionError>()));
    });
  });

  group('new game', () {
    test('starts on round 1, player 0, with 3 rolls and nothing held', () {
      final game = DiceGame(playerCount: 3, random: Random(1));
      expect(game.round, 1);
      expect(game.currentPlayer, 0);
      expect(game.rollsRemaining, 3);
      expect(game.hasRolledThisRound, isFalse);
      expect(game.held, everyElement(isFalse));
      expect(game.isOver, isFalse);
    });

    test('gives every player their own empty score card', () {
      final game = DiceGame(playerCount: 4, random: Random(1));
      for (var p = 0; p < 4; p++) {
        expect(game.scoreCardFor(p).isComplete, isFalse);
        expect(game.totalFor(p), 0);
      }
    });
  });

  group('roll', () {
    test('first roll spends a roll and marks the turn as rolled', () {
      final game = DiceGame(playerCount: 2, random: Random(1))..roll();
      expect(game.rollsRemaining, 2);
      expect(game.hasRolledThisRound, isTrue);
    });

    test('produces five dice each in 1..6', () {
      final game = DiceGame(playerCount: 2, random: Random(1))..roll();
      expect(game.dice.length, 5);
      expect(game.dice, everyElement(inInclusiveRange(1, 6)));
    });

    test('uses the injected RNG so a fixed seed is reproducible', () {
      final a = DiceGame(playerCount: 2, random: Random(42))..roll();
      final b = DiceGame(playerCount: 2, random: Random(42))..roll();
      expect(a.dice, b.dice);
    });

    test('three rolls exhaust the turn and a fourth throws', () {
      final game = DiceGame(playerCount: 2, random: Random(1));
      game.roll();
      game.roll();
      game.roll();
      expect(game.rollsRemaining, 0);
      expect(game.roll, throwsA(isA<StateError>()));
    });
  });

  group('hold', () {
    test('cannot hold before the first roll of the turn', () {
      final game = DiceGame(playerCount: 2, random: Random(1));
      expect(() => game.toggleHold(0), throwsA(isA<StateError>()));
    });

    test('toggleHold flips a die and back', () {
      final game = DiceGame(playerCount: 2, random: Random(1))..roll();
      game.toggleHold(2);
      expect(game.held[2], isTrue);
      game.toggleHold(2);
      expect(game.held[2], isFalse);
    });

    test('held dice keep their values across a roll', () {
      final game = DiceGame(playerCount: 2, random: Random(7))..roll();
      for (var i = 0; i < 5; i++) {
        game.toggleHold(i);
      }
      final before = [...game.dice];
      game.roll();
      expect(game.dice, before);
    });
  });

  group('turn and round advancement', () {
    test('commitScore records to the current player and passes the turn', () {
      final game = DiceGame(playerCount: 2, random: Random(1))..roll();
      game.commitScore(ScoreCategory.chance);

      expect(game.scoreCardFor(0).isFilled(ScoreCategory.chance), isTrue);
      expect(game.scoreCardFor(1).isFilled(ScoreCategory.chance), isFalse);
      expect(game.currentPlayer, 1);
      expect(game.round, 1);
      expect(game.rollsRemaining, 3);
      expect(game.hasRolledThisRound, isFalse);
      expect(game.held, everyElement(isFalse));
    });

    test('the round advances only when the turn wraps back to player 0', () {
      final game = DiceGame(playerCount: 3, random: Random(1));

      playTurn(game, ScoreCategory.chance); // player 0
      expect(game.round, 1);
      expect(game.currentPlayer, 1);

      playTurn(game, ScoreCategory.chance); // player 1
      expect(game.round, 1);
      expect(game.currentPlayer, 2);

      playTurn(game, ScoreCategory.chance); // player 2 -> wrap
      expect(game.round, 2);
      expect(game.currentPlayer, 0);
    });

    test('cannot commit before rolling', () {
      final game = DiceGame(playerCount: 2, random: Random(1));
      expect(
        () => game.commitScore(ScoreCategory.chance),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('standings and end of game', () {
    test('standings mirror each player score card total', () {
      final game = DiceGame(playerCount: 2, random: Random(3));
      playTurn(game, ScoreCategory.chance); // player 0
      playTurn(game, ScoreCategory.yahtzee); // player 1

      expect(game.standings, [
        game.scoreCardFor(0).total,
        game.scoreCardFor(1).total,
      ]);
    });

    test('winner is null until the game is over', () {
      final game = DiceGame(playerCount: 2, random: Random(1))..roll();
      game.commitScore(ScoreCategory.chance);
      expect(game.winner, isNull);
    });

    test('a completed game is over and names the highest-scoring seat', () {
      final game = DiceGame(playerCount: 2, random: Random(5));
      for (final category in ScoreCategory.values) {
        playTurn(game, category); // player 0
        playTurn(game, category); // player 1
      }

      expect(game.isOver, isTrue);
      expect(game.round, 16);

      final standings = game.standings;
      if (standings[0] == standings[1]) {
        expect(game.winner, isNull);
      } else {
        final best = standings[0] > standings[1] ? 0 : 1;
        expect(game.winner, best);
      }
    });
  });
}
