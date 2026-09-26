import 'package:flutter/material.dart';

import '../seat_palette.dart';

/// What the player chose on the results screen.
enum ResultsAction { rematch, menu }

/// End-of-match results: winner (or tie), final standings, and a choice of
/// Rematch or Back to menu. Pushed as a full-screen route; pops with a
/// [ResultsAction] (or null if dismissed, treated as [ResultsAction.menu]).
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({
    super.key,
    required this.standings,
    required this.winner,
    this.names,
  });

  /// Final total per seat, in seat order.
  final List<int> standings;

  /// Seat with the strictly-highest total, or null for a tie.
  final int? winner;

  /// Resolved display name per seat; falls back to [SeatPalette.label].
  final List<String>? names;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ranking = List.generate(standings.length, (p) => p)
      ..sort((a, b) => standings[b].compareTo(standings[a]));
    final accent =
        winner == null ? theme.colorScheme.primary : SeatPalette.color(winner!);
    String nameFor(int seat) => names?[seat] ?? SeatPalette.label(seat);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Icon(
                winner == null ? Icons.handshake : Icons.emoji_events,
                size: 72,
                color: accent,
              ),
              const SizedBox(height: 16),
              Text(
                winner == null ? "It's a tie!" : '${nameFor(winner!)} wins!',
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Final scores',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    for (var i = 0; i < ranking.length; i++)
                      _StandingRow(
                        rank: i + 1,
                        seat: ranking[i],
                        name: nameFor(ranking[i]),
                        total: standings[ranking[i]],
                        isWinner: ranking[i] == winner,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey('rematch_button'),
                onPressed: () =>
                    Navigator.of(context).pop(ResultsAction.rematch),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Rematch'),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const ValueKey('menu_button'),
                onPressed: () => Navigator.of(context).pop(ResultsAction.menu),
                child: const Text('Back to menu'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({
    required this.rank,
    required this.seat,
    required this.name,
    required this.total,
    required this.isWinner,
  });

  final int rank;
  final int seat;
  final String name;
  final int total;
  final bool isWinner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = SeatPalette.color(seat);

    return Container(
      key: ValueKey('standing_$seat'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isWinner
            ? color.withValues(alpha: 0.14)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: isWinner
            ? Border.all(color: color.withValues(alpha: 0.55))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: isWinner ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            '$total',
            style: theme.textTheme.titleLarge?.copyWith(
              color: isWinner ? color : null,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
