import 'cloud_store.dart';
import 'friend_service.dart';
import 'online_match_service.dart';

/// Removes an account's server-side data: friends, requests, friend code,
/// online matches and synced results. Local match history is not touched.
class AccountCleanup {
  AccountCleanup(this._friends, this._online, this._cloudFor);

  final FriendService _friends;
  final OnlineMatchService _online;
  final CloudStore Function(String uid) _cloudFor;

  Future<void> run(String uid) async {
    await _online.deleteAllFor(uid);
    await _friends.deleteAccountData(uid);
    await _cloudFor(uid).deleteAllMatches();
  }
}
