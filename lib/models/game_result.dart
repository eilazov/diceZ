/// A finished game's outcome, as stored in local history.
class GameResult {
  const GameResult({required this.playedAt, required this.totalScore});

  final DateTime playedAt;
  final int totalScore;

  Map<String, dynamic> toJson() => {
        'playedAt': playedAt.toIso8601String(),
        'totalScore': totalScore,
      };

  factory GameResult.fromJson(Map<String, dynamic> json) => GameResult(
        playedAt: DateTime.parse(json['playedAt'] as String),
        totalScore: json['totalScore'] as int,
      );
}
