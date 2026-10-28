import 'dart:math';

import 'dice_game.dart';
import 'game_mode.dart';

enum OnlineMatchStatus { pending, active, finished }

/// A two-player match played from two devices. [state] is a [DiceGame] JSON
/// snapshot; seat 0 is the challenger.
class OnlineMatch {
  const OnlineMatch({
    required this.id,
    required this.players,
    required this.names,
    required this.mode,
    required this.status,
    required this.state,
    required this.createdAt,
    this.finishedAt,
  });

  final String id;

  /// Account uids by seat.
  final List<String> players;
  final List<String> names;
  final GameMode mode;
  final OnlineMatchStatus status;
  final Map<String, dynamic> state;
  final DateTime createdAt;
  final DateTime? finishedAt;

  int? seatOf(String uid) {
    final seat = players.indexOf(uid);
    return seat < 0 ? null : seat;
  }

  DiceGame game({Random? random}) => DiceGame.fromJson(state, random: random);

  bool isMyTurn(String uid) =>
      status == OnlineMatchStatus.active && seatOf(uid) == game().currentPlayer;

  OnlineMatch copyWith({
    String? id,
    OnlineMatchStatus? status,
    Map<String, dynamic>? state,
    DateTime? finishedAt,
  }) => OnlineMatch(
    id: id ?? this.id,
    players: players,
    names: names,
    mode: mode,
    status: status ?? this.status,
    state: state ?? this.state,
    createdAt: createdAt,
    finishedAt: finishedAt ?? this.finishedAt,
  );

  Map<String, dynamic> toJson() => {
    'players': players,
    'names': names,
    'mode': mode.name,
    'status': status.name,
    'state': state,
    'createdAt': createdAt.millisecondsSinceEpoch,
    if (finishedAt != null) 'finishedAt': finishedAt!.millisecondsSinceEpoch,
  };

  factory OnlineMatch.fromJson(String id, Map<String, dynamic> json) =>
      OnlineMatch(
        id: id,
        players: List<String>.from(json['players'] as List),
        names: List<String>.from(json['names'] as List),
        mode: GameMode.fromName(json['mode'] as String?),
        status: OnlineMatchStatus.values.byName(json['status'] as String),
        state: Map<String, dynamic>.from(json['state'] as Map),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (json['createdAt'] as num).toInt(),
        ),
        finishedAt: json['finishedAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                (json['finishedAt'] as num).toInt(),
              ),
      );
}
