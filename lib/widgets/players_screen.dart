import 'package:flutter/material.dart';

import '../models/player_profile.dart';
import '../services/player_storage.dart';

/// Manage local player profiles: add, rename, delete.
class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key, this.storage = const PlayerStorage()});

  final PlayerStorage storage;

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  List<PlayerProfile>? _profiles;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profiles = await widget.storage.loadProfiles();
    if (mounted) setState(() => _profiles = profiles);
  }

  Future<void> _addProfile() async {
    final name = await _promptName(context, title: 'Add player');
    if (name == null || name.isEmpty) return;
    await widget.storage.addProfile(name);
    await _load();
  }

  Future<void> _renameProfile(PlayerProfile profile) async {
    final name = await _promptName(
      context,
      title: 'Rename player',
      initial: profile.name,
    );
    if (name == null || name.isEmpty || name == profile.name) return;
    await widget.storage.renameProfile(profile.id, name);
    await _load();
  }

  Future<void> _deleteProfile(PlayerProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${profile.name}?'),
        content: const Text(
          'Past games stay in history, but this player will no longer have '
          'their own statistics.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.storage.deleteProfile(profile.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final profiles = _profiles;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Players'),
        actions: [
          IconButton(
            key: const ValueKey('add_player_button'),
            onPressed: _addProfile,
            icon: const Icon(Icons.person_add),
          ),
        ],
      ),
      body: profiles == null
          ? const Center(child: CircularProgressIndicator())
          : profiles.isEmpty
              ? const _EmptyState()
              : ListView(
                  children: [
                    for (final profile in profiles)
                      ListTile(
                        key: ValueKey('player_${profile.id}'),
                        title: Text(profile.name),
                        onTap: () => _renameProfile(profile),
                        trailing: IconButton(
                          key: ValueKey('delete_${profile.id}'),
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteProfile(profile),
                        ),
                      ),
                  ],
                ),
    );
  }
}

Future<String?> _promptName(
  BuildContext context, {
  required String title,
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        key: const ValueKey('player_name_field'),
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey('save_player_name'),
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 72,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('No players yet.', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Add a player to see their name in-game and their own '
              'statistics.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
