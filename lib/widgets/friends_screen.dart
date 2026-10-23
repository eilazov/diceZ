import 'package:flutter/material.dart';

import '../models/friend_profile.dart';
import '../services/auth_service.dart';
import '../services/firestore_friend_store.dart';
import '../services/friend_service.dart';
import 'friend_code_tile.dart';

String accountDisplayName(AccountUser user) {
  final name = user.displayName?.trim();
  if (name != null && name.isNotEmpty) return name;
  return user.email?.split('@').first ?? 'Player';
}

/// Your friend code, search-by-code to send a request, and your friends and
/// pending requests.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key, required this.user, this.service});

  final AccountUser user;

  /// Defaults to a Firestore-backed [FriendService]; injectable for tests.
  final FriendService? service;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  late final FriendService _service =
      widget.service ?? FriendService(FirestoreFriendStore());
  final _controller = TextEditingController();
  FriendProfile? _me;
  FriendsOverview? _overview;
  Object? _loadError;
  String? _message;
  bool _messageIsError = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final me = await _service.myProfile(
        widget.user.uid,
        accountDisplayName(widget.user),
      );
      final overview = await _service.load(widget.user.uid);
      if (!mounted) return;
      setState(() {
        _me = me;
        _overview = overview;
        _loadError = null;
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'Something went wrong. Try again.';
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final me = _me;
    if (me == null) return;
    await _run(() async {
      final result = await _service.sendRequest(me, _controller.text);
      final target = result.target;
      final sent = result.status == AddFriendStatus.sent;
      if (!mounted) return;
      setState(() {
        _messageIsError = !sent;
        _message = switch (result.status) {
          AddFriendStatus.sent => 'Request sent to ${target?.name}.',
          AddFriendStatus.invalidCode => 'Codes are 6 characters, like K7M2QX.',
          AddFriendStatus.notFound => 'No player has that code.',
          AddFriendStatus.self => "That's your own code.",
          AddFriendStatus.alreadyFriends =>
            'You and ${target?.name} are already friends.',
          AddFriendStatus.alreadyRequested =>
            'You already sent ${target?.name} a request.',
          AddFriendStatus.theyRequestedYou =>
            '${target?.name} already sent you a request — accept it below.',
        };
        if (sent) _controller.clear();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _body(context),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final me = _me;
    final overview = _overview;
    if (_loadError != null && me == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Couldn't load friends."),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (me == null || overview == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FriendCodeTile(code: me.code),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: "Friend's code",
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _busy ? null : _send,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
              child: const Text('Send request'),
            ),
          ],
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _messageIsError
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            ),
          ),
        if (overview.incoming.isNotEmpty) ...[
          _header(context, 'Requests'),
          for (final p in overview.incoming)
            ListTile(
              title: Text(p.name),
              subtitle: Text(p.code),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Decline',
                    icon: const Icon(Icons.close),
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => _service.decline(widget.user.uid, p.uid),
                          ),
                  ),
                  IconButton(
                    tooltip: 'Accept',
                    icon: const Icon(Icons.check),
                    onPressed: _busy
                        ? null
                        : () => _run(() => _service.accept(me, p)),
                  ),
                ],
              ),
            ),
        ],
        if (overview.outgoing.isNotEmpty) ...[
          _header(context, 'Sent'),
          for (final p in overview.outgoing)
            ListTile(
              title: Text(p.name),
              subtitle: const Text('Waiting for them to accept'),
              trailing: IconButton(
                tooltip: 'Cancel request',
                icon: const Icon(Icons.close),
                onPressed: _busy
                    ? null
                    : () => _run(() => _service.cancel(widget.user.uid, p.uid)),
              ),
            ),
        ],
        _header(context, 'Friends'),
        if (overview.friends.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No friends yet. Share your code or enter a friend\'s.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final p in overview.friends)
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(p.name),
            subtitle: Text(p.code),
            trailing: IconButton(
              tooltip: 'Remove friend',
              icon: const Icon(Icons.person_remove),
              onPressed: _busy
                  ? null
                  : () => _run(() => _service.remove(widget.user.uid, p.uid)),
            ),
          ),
      ],
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 4),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}
