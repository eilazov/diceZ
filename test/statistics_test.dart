import 'package:flutter_test/flutter_test.dart';
import 'package:dice_zee/models/game_mode.dart';
import 'package:dice_zee/models/game_result.dart';
import 'package:dice_zee/models/score_card.dart';
import 'package:dice_zee/models/statistics.dart';

PlayerScore player(Map<ScoreCategory, int> overrides, {String? profileId}) =>
    PlayerScore(
      categoryScores: {
        for (final c in ScoreCategory.values) c: overrides[c] ?? 0,
      },
      profileId: profileId,
    );

GameResult game(List<PlayerScore> players) => GameResult(
  playedAt: DateTime.utc(2026, 1, 1),
  playerCount: players.length,
  players: players,
);

void main() {
  group('empty history', () {
    final stats = Statistics.from(const []);

    test('reports nothing played', () {
      expect(stats.gamesPlayed, 0);
      expect(stats.averageScore, 0.0);
    });

    test('best and worst score are zero', () {
      expect(stats.bestScore, 0);
      expect(stats.worstScore, 0);
    });

    test('best-by-category is zero for every category', () {
      for (final c in ScoreCategory.values) {
        expect(stats.bestByCategory[c], 0);
      }
    });
  });

  group('with games', () {
    final history = [
      game([
        player({ScoreCategory.sixes: 18, ScoreCategory.yahtzee: 100}), // 118
        player({ScoreCategory.chance: 20}), //  20
      ]),
      game([
        player({ScoreCategory.fullHouse: 25, ScoreCategory.sixes: 12}), //  37
        player({ScoreCategory.yahtzee: 100, ScoreCategory.chance: 25}), // 125
      ]),
    ];

    final stats = Statistics.from(history);

    test('counts games', () {
      expect(stats.gamesPlayed, 2);
    });

    test('averages every player total across every game', () {
      // (118 + 20 + 37 + 125) / 4 = 75.0
      expect(stats.averageScore, 75.0);
    });

    test('best and worst score are the highest and lowest single totals', () {
      expect(stats.bestScore, 125);
      expect(stats.worstScore, 20);
    });

    test('best-by-category takes the max seen anywhere', () {
      expect(stats.bestByCategory[ScoreCategory.sixes], 18);
      expect(stats.bestByCategory[ScoreCategory.yahtzee], 100);
      expect(stats.bestByCategory[ScoreCategory.chance], 25);
      expect(stats.bestByCategory[ScoreCategory.fullHouse], 25);
      expect(stats.bestByCategory[ScoreCategory.ones], 0);
    });
  });

  group('scoped to a profile', () {
    final history = [
      game([
        player({
          ScoreCategory.sixes: 18,
          ScoreCategory.yahtzee: 100,
        }, profileId: 'levon'), // 118, sole winner
        player({ScoreCategory.chance: 20}), // 20, guest
      ]),
      game([
        player({ScoreCategory.fullHouse: 30}, profileId: 'anna'), // 30
        player({ScoreCategory.chance: 30}, profileId: 'levon'), // 30, tie
      ]),
      game([
        player({ScoreCategory.chance: 10}, profileId: 'levon'), // 10
        player({ScoreCategory.chance: 50}, profileId: 'anna'), // 50, winner
      ]),
    ];

    final levon = Statistics.from(history, profileId: 'levon');

    test('games played counts only games this profile appeared in', () {
      expect(levon.gamesPlayed, 3);
    });

    test("average score is scoped to this profile's totals", () {
      // (118 + 30 + 10) / 3
      expect(levon.averageScore, closeTo(52.67, 0.01));
    });

    test('best-by-category is scoped to this profile', () {
      expect(levon.bestByCategory[ScoreCategory.yahtzee], 100);
      expect(levon.bestByCategory[ScoreCategory.chance], 30); // not anna's 50
    });

    test("best and worst score are scoped to this profile's totals", () {
      expect(levon.bestScore, 118); // not anna's 50
      expect(levon.worstScore, 10); // not the guest's 20
    });

    test('wins counts strict-highest games only; ties credit nobody', () {
      expect(levon.wins, 1); // game 1 only
    });
  });

  test('a zero-player game is skipped by the wins tally, not thrown on', () {
    final history = [
      game(const []), // malformed/corrupted entry; must not throw
      game([
        player({ScoreCategory.chance: 10}, profileId: 'levon'), // loses
        player({ScoreCategory.chance: 50}, profileId: 'anna'),
      ]),
    ];

    final stats = Statistics.from(history, profileId: 'levon');

    expect(stats.wins, 0);
  });

  test('Statistics.from with no profileId matches the pre-scoping numbers', () {
    final history = [
      game([
        player({ScoreCategory.sixes: 18}, profileId: 'levon'),
        player({ScoreCategory.chance: 20}),
      ]),
    ];

    final everyone = Statistics.from(history);

    expect(everyone.gamesPlayed, 1);
    expect(everyone.averageScore, 19.0); // (18 + 20) / 2
  });

  group('extended figures', () {
    GameResult at(int day, List<PlayerScore> players) => GameResult(
      playedAt: DateTime.utc(2026, 1, day),
      playerCount: players.length,
      players: players,
    );

    PlayerScore p(int chance, {String? id, String? name, int yahtzee = 0}) =>
        PlayerScore(
          categoryScores: {
            for (final c in ScoreCategory.values) c: 0,
            ScoreCategory.chance: chance,
            ScoreCategory.yahtzee: yahtzee,
          },
          profileId: id,
          name: name,
        );

    // Stored newest first, like GameStorage.
    final history = [
      at(5, [
        p(10, id: 'l', name: 'Levon'),
        p(40, id: 'a', name: 'Anna'),
      ]), // L loses
      at(4, [
        p(30, id: 'l', name: 'Levon'),
        p(20, id: 'a', name: 'Anna'),
      ]), // L wins by 10
      at(3, [
        p(50, id: 'l', name: 'Levon', yahtzee: 100),
        p(20, id: 'a', name: 'Anna'),
      ]), // L wins by 130
      at(2, [
        p(25, id: 'l', name: 'Levon'),
        p(25, id: 'a', name: 'Anna'),
      ]), // tie
      at(1, [
        p(30, id: 'l', name: 'Levon'),
        p(5, id: 'a', name: 'Anna'),
        p(0),
      ]), // L wins by 25
    ];
    final levon = Statistics.from(history, profileId: 'l');

    test('win rate is wins over games', () {
      expect(levon.wins, 3);
      expect(levon.winRate, closeTo(0.6, 1e-9));
    });

    test('streaks follow chronological order; a tie or loss breaks one', () {
      expect(levon.currentWinStreak, 0); // latest game was lost
      expect(levon.longestWinStreak, 2); // days 3 and 4
    });

    test('current streak counts back from the latest game', () {
      final s = Statistics.from(history.sublist(1), profileId: 'l');
      expect(s.currentWinStreak, 2);
    });

    test('biggest margin is the largest lead in a game this profile won', () {
      expect(levon.biggestMargin, 130);
    });

    test('everyone: biggest margin is the largest lead in any game', () {
      expect(Statistics.from(history).biggestMargin, 130);
    });

    test('dice zee count is how many cards scored the category', () {
      expect(levon.yahtzeeCount, 1);
    });

    test('average and zero-count per category', () {
      // chance: 10, 30, 50, 25, 30 -> 29.0
      expect(
        levon.averageByCategory[ScoreCategory.chance],
        closeTo(29.0, 1e-9),
      );
      expect(levon.zeroCountByCategory[ScoreCategory.chance], 0);
      expect(levon.zeroCountByCategory[ScoreCategory.ones], 5);
      expect(levon.zeroCountByCategory[ScoreCategory.yahtzee], 4);
    });

    test('recent average covers only the last 10 games', () {
      final many = [
        for (var d = 20; d >= 1; d--)
          at(d, [p(d <= 10 ? 10 : 100, id: 'l'), p(0, id: 'a')]),
      ];
      final s = Statistics.from(many, profileId: 'l');
      expect(s.recentAverage, 100.0); // days 11..20
      expect(s.averageScore, 55.0);
    });

    test('head to head tallies each named opponent', () {
      expect(levon.headToHead, hasLength(1));
      final anna = levon.headToHead.single;
      expect(anna.opponentId, 'a');
      expect(anna.name, 'Anna');
      expect((anna.wins, anna.losses, anna.ties), (3, 1, 1));
    });

    test('head to head is empty when unscoped', () {
      expect(Statistics.from(history).headToHead, isEmpty);
    });

    test('splits games, average and wins by player count', () {
      final two = levon.byPlayerCount[2]!;
      expect(two.games, 4);
      expect(two.wins, 2);
      expect(two.averageScore, closeTo((10 + 30 + 150 + 25) / 4, 1e-9));
      final three = levon.byPlayerCount[3]!;
      expect((three.games, three.wins), (1, 1));
      expect(levon.byPlayerCount.containsKey(4), isFalse);
    });
  });

  group('game mode', () {
    GameResult modeGame(GameMode mode, int chance, {int bonus = 0}) =>
        GameResult(
          playedAt: DateTime.utc(2026, 1, 1),
          playerCount: 1,
          mode: mode,
          players: [
            PlayerScore(
              categoryScores: {
                for (final c in ScoreCategory.values) c: 0,
                ScoreCategory.chance: chance,
              },
              upperBonus: bonus,
            ),
          ],
        );

    final history = [
      modeGame(GameMode.standard, 100, bonus: 35),
      modeGame(GameMode.standard, 50),
      modeGame(GameMode.extended, 200),
    ];

    test('only games of the requested mode count', () {
      final standard = Statistics.from(history, mode: GameMode.standard);
      expect(standard.gamesPlayed, 2);
      expect(standard.bestScore, 135); // bonus included
      expect(standard.worstScore, 50);

      final extended = Statistics.from(history, mode: GameMode.extended);
      expect(extended.gamesPlayed, 1);
      expect(extended.bestScore, 200);
    });

    test('the default mode is extended', () {
      expect(Statistics.from(history).gamesPlayed, 1);
    });

    test('per-category figures cover only the mode sheet', () {
      final standard = Statistics.from(history, mode: GameMode.standard);
      expect(standard.bestByCategory.keys, GameMode.standard.categories);
      expect(standard.averageByCategory.keys, GameMode.standard.categories);
      expect(standard.zeroCountByCategory.keys, GameMode.standard.categories);
      expect(standard.zeroCountByCategory[ScoreCategory.ones], 2);
    });

    test('the upper bonus counts how often it was earned', () {
      expect(Statistics.from(history, mode: GameMode.standard).bonusCount, 1);
      expect(Statistics.from(history, mode: GameMode.extended).bonusCount, 0);
    });
  });
}
