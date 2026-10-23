import 'dart:async';

import 'package:flutter/material.dart';

import '../models/game_mode.dart';
import '../models/statistics.dart';
import '../services/game_storage.dart';
import '../services/sync_service.dart';
import 'bottom_padding.dart';
import 'score_table.dart';

/// One player's (or "Everyone"'s) stats, scoped via [profileId].
class PlayerStatsScreen extends StatefulWidget {
  const PlayerStatsScreen({
    super.key,
    required this.title,
    this.profileId,
    this.mode = GameMode.extended,
    this.storage = const GameStorage(),
  });

  /// App-bar title: a profile's name, or "Everyone".
  final String title;

  /// Scope stats to this profile; null means every game ("Everyone").
  final String? profileId;

  /// Only games of this rule set are counted.
  final GameMode mode;

  final GameStorage storage;

  @override
  State<PlayerStatsScreen> createState() => _PlayerStatsScreenState();
}

class _PlayerStatsScreenState extends State<PlayerStatsScreen> {
  late Future<Statistics> _stats = _load();
  StreamSubscription<void>? _syncSub;

  Future<Statistics> _load() => widget.storage.loadHistory().then(
    (history) => Statistics.from(
      history,
      profileId: widget.profileId,
      mode: widget.mode,
    ),
  );

  @override
  void initState() {
    super.initState();
    // A cloud pull may bring in matches from other devices.
    _syncSub = SyncService.instance.changes.listen((_) {
      if (mounted) setState(() => _stats = _load());
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.title} · ${widget.mode.label}')),
      body: FutureBuilder<Statistics>(
        future: _stats,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _ErrorState();
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stats = snapshot.data!;
          if (stats.gamesPlayed == 0) {
            return const _EmptyState();
          }
          return _StatsBody(
            stats: stats,
            scoped: widget.profileId != null,
            mode: widget.mode,
          );
        },
      ),
    );
  }
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
              Icons.casino_outlined,
              size: 72,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No games played yet.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Finish a match and its scores show up here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Start a game'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

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
              Icons.error_outline,
              size: 72,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              "Couldn't load stats. Try again later.",
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

class _StatsBody extends StatelessWidget {
  const _StatsBody({
    required this.stats,
    required this.scoped,
    required this.mode,
  });

  final Statistics stats;
  final GameMode mode;

  /// Per-profile view: adds wins, streaks and head-to-head, which are
  /// meaningless for "Everyone".
  final bool scoped;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delta = stats.recentAverage - stats.averageScore;
    final cards = <(String, String, String)>[
      ('stat_games', '${stats.gamesPlayed}', 'Games played'),
      if (scoped) ('stat_wins', '${stats.wins}', 'Wins'),
      if (scoped)
        ('stat_win_rate', '${(stats.winRate * 100).round()}%', 'Win rate'),
      ('stat_avg', stats.averageScore.toStringAsFixed(1), 'Average score'),
      ('stat_best_game', '${stats.bestScore}', 'Best game'),
      ('stat_worst_game', '${stats.worstScore}', 'Worst game'),
      if (scoped)
        ('stat_streak', '${stats.currentWinStreak}', 'Current win streak'),
      if (scoped)
        ('stat_best_streak', '${stats.longestWinStreak}', 'Longest win streak'),
      ('stat_margin', '${stats.biggestMargin}', 'Biggest winning margin'),
      ('stat_yahtzee', '${stats.yahtzeeCount}', 'Dice Zees'),
      if (stats.bonusCount > 0 || mode == GameMode.standard)
        ('stat_bonus', '${stats.bonusCount}', 'Upper bonuses'),
      (
        'stat_recent',
        stats.recentAverage.toStringAsFixed(1),
        'Last ${Statistics.recentWindow} avg '
            '(${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)})',
      ),
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, BottomPadding.of(context)),
      children: [
        for (var i = 0; i < cards.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  statKey: cards[i].$1,
                  value: cards[i].$2,
                  label: cards[i].$3,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: i + 1 < cards.length
                    ? _StatCard(
                        statKey: cards[i + 1].$1,
                        value: cards[i + 1].$2,
                        label: cards[i + 1].$3,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Text('By player count', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final entry in stats.byPlayerCount.entries)
          _InfoRow(
            rowKey: 'count_${entry.key}',
            title: '${entry.key} players',
            detail: [
              '${entry.value.games} games',
              'avg ${entry.value.averageScore.toStringAsFixed(1)}',
              if (scoped) '${entry.value.wins} wins',
            ].join(' · '),
          ),
        if (scoped && stats.headToHead.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Head to head', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final h in stats.headToHead)
            _InfoRow(
              rowKey: 'h2h_${h.opponentId}',
              title: 'vs ${h.name}',
              detail: '${h.wins}W · ${h.losses}L · ${h.ties}T',
            ),
        ],
        const SizedBox(height: 24),
        Text('By category', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: [
            for (final entry in stats.bestByCategory.entries)
              _BestTile(
                tileKey: 'best_${entry.key.name}',
                label: categoryLabel(entry.key),
                value: entry.value,
                detail:
                    'avg ${stats.averageByCategory[entry.key]!.toStringAsFixed(1)}'
                    ' · ${stats.zeroCountByCategory[entry.key]}× zero',
              ),
          ],
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.rowKey,
    required this.title,
    required this.detail,
  });

  final String rowKey;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: ValueKey(rowKey),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(title, style: theme.textTheme.bodyLarge)),
          Text(
            detail,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.statKey,
    required this.value,
    required this.label,
  });

  final String statKey;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: ValueKey(statKey),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _BestTile extends StatelessWidget {
  const _BestTile({
    required this.tileKey,
    required this.label,
    required this.value,
    required this.detail,
  });

  final String tileKey;
  final String label;
  final int value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: ValueKey(tileKey),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$value',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
