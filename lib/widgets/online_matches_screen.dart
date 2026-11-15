import 'package:flutter/material.dart';

import '../models/dice_game.dart';
import '../models/friend_profile.dart';
import '../models/online_match.dart';
import '../services/auth_service.dart';
import '../services/firestore_friend_store.dart';
import '../services/firestore_online_match_store.dart';
import '../services/friend_service.dart';
import '../services/online_match_service.dart';
import 'challenge_mode_dialog.dart';
import 'friends_screen.dart';
import 'online_game_screen.dart';

/// The online hub: invites, your turn / their turn matches and recent
/// finished ones, plus starting a new game and managing friends.
class OnlineMatchesScreen extends StatefulWidget {
  const OnlineMatchesScreen({
    super.key,
    required this.user,
    this.service,
    this.friendService,
  });

  final AccountUser user;

  /// Defaults to a Firestore-backed service; injectable for tests.
  final OnlineMatchService? service;

  /// Defaults to a Firestore-backed [FriendService]; injectable for tests.
  final FriendService? friendService;

  @override
  State<OnlineMatchesScreen> createState() => _OnlineMatchesScreenState();
}

class _OnlineMatchesScreenState extends State<OnlineMatchesScreen> {
  late final OnlineMatchService _service =
      widget.service ?? OnlineMatchService(FirestoreOnlineMatchStore());
  late final FriendService _friends =
      widget.friendService ?? FriendService(FirestoreFriendStore());
  late final Stream<List<OnlineMatch>> _stream = _service.watchFor(
    widget.user.uid,
  );

  String _opponent(OnlineMatch m) =>
      m.names[1 - (m.seatOf(widget.user.uid) ?? 0)];

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Try again.')),
        );
      }
    }
  }

  void _open(OnlineMatch m) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => OnlineGameScreen(
        user: widget.user,
        matchId: m.id,
        service: widget.service,
      ),
    ),
  );

  void _openFriends() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => FriendsScreen(
        user: widget.user,
        service: widget.friendService,
        onlineService: widget.service,
      ),
    ),
  );

  bool _starting = false;

  Future<void> _startNewGame() => _guard(() async {
    final uid = widget.user.uid;
    final me = await _friends.myProfile(uid, accountDisplayName(widget.user));
    final friends = (await _friends.load(uid)).friends;
    if (!mounted) return;
    final friend = await showModalBottomSheet<FriendProfile>(
      context: context,
      builder: (sheet) => SafeArea(
        child: friends.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Add a friend first'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(sheet).pop();
                        _openFriends();
                      },
                      child: const Text('Open Friends'),
                    ),
                  ],
                ),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final f in friends)
                    ListTile(
                      title: Text(f.name),
                      onTap: () => Navigator.of(sheet).pop(f),
                    ),
                ],
              ),
      ),
    );
    if (friend == null || !mounted) return;
    final mode = await showChallengeModeDialog(context, friend.name);
    if (mode == null) return;
    await _service.challenge(me, friend, mode);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Challenge sent to ${friend.name}.')),
    );
  });

  /// One New game flow at a time: a second tap while the friend list loads
  /// (or the picker is open) must not stack another picker.
  Future<void> _newGame() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      await _startNewGame();
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.user.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Online games'),
        actions: [
          IconButton(
            key: const ValueKey('friends_action'),
            tooltip: 'Friends',
            icon: const Icon(Icons.group),
            onPressed: _openFriends,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('new_game_button'),
        onPressed: _starting ? null : _newGame,
        icon: const Icon(Icons.add),
        label: const Text('New game'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<OnlineMatch>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text("Couldn't load online games."));
            }
            final all = snapshot.data;
            if (all == null) {
              return const Center(child: CircularProgressIndicator());
            }
            bool pending(OnlineMatch m) =>
                m.status == OnlineMatchStatus.pending;
            final invites = [
              for (final m in all)
                if (pending(m) && m.seatOf(uid) == 1) m,
            ];
            final sent = [
              for (final m in all)
                if (pending(m) && m.seatOf(uid) == 0) m,
            ];
            final active =
                [
                  for (final m in all)
                    if (m.status == OnlineMatchStatus.active) m,
                ]..sort(
                  (a, b) => a.isMyTurn(uid) == b.isMyTurn(uid)
                      ? 0
                      : a.isMyTurn(uid)
                      ? -1
                      : 1,
                );
            final finished = [
              for (final m in all)
                if (m.status == OnlineMatchStatus.finished) m,
            ]..sort((a, b) => b.finishedAt!.compareTo(a.finishedAt!));

            if (all.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No online games yet. Tap New game to challenge a friend.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              children: [
                if (invites.isNotEmpty) _header('Invites'),
                for (final m in invites)
                  ListTile(
                    title: Text('${_opponent(m)} challenged you'),
                    subtitle: Text(m.mode.label),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Decline',
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                              _guard(() => _service.decline(m, uid)),
                        ),
                        IconButton(
                          tooltip: 'Accept',
                          icon: const Icon(Icons.check),
                          onPressed: () => _guard(() async {
                            await _service.accept(m, uid);
                            if (mounted) _open(m);
                          }),
                        ),
                      ],
                    ),
                  ),
                if (active.isNotEmpty) _header('Active'),
                for (final m in active)
                  ListTile(
                    title: Text('vs ${_opponent(m)}'),
                    subtitle: Text(
                      m.isMyTurn(uid) ? 'Your turn' : 'Their turn',
                    ),
                    trailing: Icon(
                      m.isMyTurn(uid) ? Icons.casino : Icons.hourglass_empty,
                    ),
                    onTap: () => _open(m),
                  ),
                if (sent.isNotEmpty) _header('Waiting for a reply'),
                for (final m in sent)
                  ListTile(
                    title: Text(_opponent(m)),
                    subtitle: Text(m.mode.label),
                    trailing: IconButton(
                      tooltip: 'Withdraw',
                      icon: const Icon(Icons.close),
                      onPressed: () => _guard(() => _service.decline(m, uid)),
                    ),
                  ),
                if (finished.isNotEmpty) _header('Finished'),
                for (final m in finished.take(5))
                  ListTile(
                    title: Text('vs ${_opponent(m)}'),
                    subtitle: Text(_score(m, uid)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _score(OnlineMatch m, String uid) {
    final DiceGame game = m.game();
    final me = m.seatOf(uid) ?? 0;
    final mine = game.standings[me];
    final theirs = game.standings[1 - me];
    final verdict = mine == theirs ? 'Tie' : (mine > theirs ? 'Won' : 'Lost');
    return '$verdict · $mine – $theirs';
  }

  Widget _header(String text) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 4),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}
