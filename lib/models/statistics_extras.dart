/// Win/loss/tie record against one named opponent.
class HeadToHead {
  const HeadToHead({
    required this.opponentId,
    required this.name,
    required this.wins,
    required this.losses,
    required this.ties,
  });

  final String opponentId;
  final String name;
  final int wins;
  final int losses;
  final int ties;

  int get games => wins + losses + ties;
}

/// Figures for the games played with one particular number of players.
class PlayerCountStats {
  const PlayerCountStats({
    required this.games,
    required this.averageScore,
    required this.wins,
  });

  final int games;
  final double averageScore;
  final int wins;
}
