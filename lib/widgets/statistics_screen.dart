import 'package:flutter/material.dart';

import '../models/statistics.dart';
import '../services/game_storage.dart';
import 'score_table.dart';

/// Aggregate statistics across every stored game.
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key, this.storage = const GameStorage()});

  final GameStorage storage;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late final Future<Statistics> _stats =
      widget.storage.loadHistory().then(Statistics.from);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: FutureBuilder<Statistics>(
        future: _stats,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stats = snapshot.data!;
          if (stats.gamesPlayed == 0) {
            return const Center(child: Text('No games played yet.'));
          }
          return _StatsBody(stats: stats);
        },
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.stats});

  final Statistics stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Games played: ${stats.gamesPlayed}',
            style: theme.textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            'Average score: ${stats.averageScore.toStringAsFixed(1)}',
            style: theme.textTheme.titleMedium,
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Best ever by category', style: theme.textTheme.titleMedium),
        ),
        for (final entry in stats.bestByCategory.entries)
          ListTile(
            key: ValueKey('best_${entry.key.name}'),
            dense: true,
            title: Text(categoryLabel(entry.key)),
            trailing: Text(
              '${entry.value}',
              style: theme.textTheme.bodyLarge,
            ),
          ),
      ],
    );
  }
}
