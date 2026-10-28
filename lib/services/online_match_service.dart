import '../models/dice_game.dart';
import '../models/friend_profile.dart';
import '../models/game_mode.dart';
import '../models/game_result.dart';
import '../models/online_match.dart';
import 'online_match_store.dart';

/// Rules for two-player online matches: who may accept, decline, and save a
/// turn. The active player's device rolls; there is no server-side referee.
class OnlineMatchService {
  OnlineMatchService(this._store);

  final OnlineMatchStore _store;

  Stream<List<OnlineMatch>> watchFor(String uid) => _store.watchFor(uid);
  Stream<OnlineMatch?> watch(String id) => _store.watch(id);

  Future<OnlineMatch> challenge(
    FriendProfile me,
    FriendProfile friend,
    GameMode mode,
  ) async {
    final match = OnlineMatch(
      id: '',
      players: [me.uid, friend.uid],
      names: [me.name, friend.name],
      mode: mode,
      status: OnlineMatchStatus.pending,
      state: DiceGame(playerCount: 2, mode: mode).toJson(),
      createdAt: DateTime.now(),
    );
    return match.copyWith(id: await _store.create(match));
  }

  Future<OnlineMatch> accept(OnlineMatch match, String uid) async {
    if (match.status != OnlineMatchStatus.pending || match.seatOf(uid) != 1) {
      throw StateError('only the invited player can accept a pending match');
    }
    final accepted = match.copyWith(status: OnlineMatchStatus.active);
    await _store.update(accepted);
    return accepted;
  }

  /// Declines an invite, or withdraws one you sent.
  Future<void> decline(OnlineMatch match, String uid) async {
    if (match.seatOf(uid) == null) {
      throw StateError('not a player in this match');
    }
    await _store.delete(match.id);
  }

  /// Writes [game] as the new state. Only the player whose turn it is in the
  /// stored match may do so; the match finishes with the last commit.
  Future<OnlineMatch> saveTurn(
    OnlineMatch match,
    String uid,
    DiceGame game,
  ) async {
    if (match.status != OnlineMatchStatus.active || !match.isMyTurn(uid)) {
      throw StateError("not this player's turn");
    }
    final saved = game.isOver
        ? match.copyWith(
            state: game.toJson(),
            status: OnlineMatchStatus.finished,
            finishedAt: DateTime.now(),
          )
        : match.copyWith(state: game.toJson());
    await _store.update(saved);
    return saved;
  }

  /// The finished match as a history entry. [myProfileId] is the local
  /// profile linked to this device's account; the opponent stays a guest.
  GameResult resultOf(OnlineMatch match, {String? myUid, String? myProfileId}) {
    final game = match.game();
    final mySeat = myUid == null ? null : match.seatOf(myUid);
    return GameResult(
      playedAt: match.finishedAt ?? match.createdAt,
      playerCount: 2,
      mode: match.mode,
      players: [
        for (var p = 0; p < 2; p++)
          PlayerScore(
            categoryScores: {
              for (final c in match.mode.categories)
                c: game.scoreCardFor(p).scoreOf(c) ?? 0,
            },
            upperBonus: game.scoreCardFor(p).upperBonus,
            profileId: p == mySeat ? myProfileId : null,
            name: match.names[p],
          ),
      ],
    );
  }
}
