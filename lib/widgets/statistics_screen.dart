import 'package:flutter/material.dart';

import '../models/game_result.dart';
import '../models/player_profile.dart';
import '../models/statistics.dart';
import '../services/game_storage.dart';
import '../services/player_storage.dart';
import 'player_stats_screen.dart';

/// Lists "Everyone" plus one row per registered player profile; tap a row
/// for its scoped statistics.
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
  late final Future<_Data> _data = Future.wait([
    widget.storage.loadHistory(),
    widget.playerStorage.loadProfiles(),
  ]).then(
    (results) => (
      results[0] as List<GameResult>,
      results[1] as List<PlayerProfile>,
    ),
  );

  void _open(BuildContext context, {required String title, String? profileId}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerStatsScreen(
          title: title,
          profileId: profileId,
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
    final stats = Statistics.from(history, profileId: profile.id);
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
          return ListView(
            children: [
              ListTile(
                key: const ValueKey('stats_everyone'),
                title: const Text('Everyone'),
                subtitle: Text('${history.length} games'),
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
