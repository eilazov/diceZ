import 'dart:async';

import 'package:flutter/material.dart';

import '../models/game_mode.dart';
import '../models/game_result.dart';
import '../models/player_profile.dart';
import '../models/statistics.dart';
import '../services/game_storage.dart';
import '../services/player_storage.dart';
import '../services/sync_service.dart';
import 'player_stats_screen.dart';

/// A game-mode switch, then "Everyone" plus one row per registered player
/// profile; tap a row for its scoped statistics in the chosen mode.
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({
    super.key,
    this.storage = const GameStorage(),
    this.playerStorage = const PlayerStorage(),
  });

  final GameStorage storage;
  final PlayerStorage playerStorage;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

typedef _Data = (List<GameResult>, List<PlayerProfile>);

class _StatisticsScreenState extends State<StatisticsScreen> {
  /// The player's explicit choice; until then the mode of the latest match.
  GameMode? _picked;
  GameMode _mode = GameMode.standard;
  late Future<_Data> _data = _load();
  StreamSubscription<void>? _syncSub;

  Future<_Data> _load() =>
      Future.wait([
        widget.storage.loadHistory(),
        widget.playerStorage.loadProfiles(),
      ]).then(
        (results) =>
            (results[0] as List<GameResult>, results[1] as List<PlayerProfile>),
      );

  @override
  void initState() {
    super.initState();
    // A cloud pull may bring in matches and players from other devices.
    _syncSub = SyncService.instance.changes.listen((_) {
      if (mounted) setState(() => _data = _load());
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  void _open(BuildContext context, {required String title, String? profileId}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerStatsScreen(
          title: title,
          profileId: profileId,
          mode: _mode,
          storage: widget.storage,
        ),
      ),
    );
  }

  Widget _profileRow(
    BuildContext context,
    List<GameResult> history,
    PlayerProfile profile,
  ) {
    final stats = Statistics.from(history, profileId: profile.id, mode: _mode);
    return ListTile(
      key: ValueKey('stats_${profile.id}'),
      title: Text(profile.name),
      subtitle: Text('${stats.gamesPlayed} games · ${stats.wins} wins'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _open(context, title: profile.name, profileId: profile.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: FutureBuilder<_Data>(
        future: _data,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final (history, profiles) = snapshot.data!;
          if (_picked == null && history.isNotEmpty) {
            _mode = history
                .reduce((a, b) => a.playedAt.isAfter(b.playedAt) ? a : b)
                .mode;
          }
          final everyone = Statistics.from(history, mode: _mode);
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: SegmentedButton<GameMode>(
                    key: const ValueKey('stats_mode_selector'),
                    segments: [
                      for (final mode in GameMode.values)
                        ButtonSegment(value: mode, label: Text(mode.label)),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) => setState(() {
                      _picked = s.first;
                      _mode = s.first;
                    }),
                  ),
                ),
              ),
              ListTile(
                key: const ValueKey('stats_everyone'),
                title: const Text('Everyone'),
                subtitle: Text('${everyone.gamesPlayed} games'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(context, title: 'Everyone'),
              ),
              for (final profile in profiles)
                _profileRow(context, history, profile),
            ],
          );
        },
      ),
    );
  }
}
