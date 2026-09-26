import 'package:flutter/material.dart';

import '../models/player_profile.dart';
import '../seat_palette.dart';
import '../services/player_storage.dart';
import 'game_screen.dart';

/// Assign a profile (or leave Guest) to each seat before starting a match,
/// shown only when 2+ profiles are registered.
class PlayerSelectScreen extends StatefulWidget {
  const PlayerSelectScreen({
    super.key,
    required this.playerCount,
    this.storage = const PlayerStorage(),
  });

  final int playerCount;
  final PlayerStorage storage;

  @override
  State<PlayerSelectScreen> createState() => _PlayerSelectScreenState();
}

class _PlayerSelectScreenState extends State<PlayerSelectScreen> {
  late final Future<List<PlayerProfile>> _profiles =
      widget.storage.loadProfiles();
  late final List<PlayerProfile?> _seats =
      List<PlayerProfile?>.filled(widget.playerCount, null);

  void _assign(int seat, PlayerProfile? profile) {
    setState(() => _seats[seat] = profile);
  }

  void _start() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => GameScreen(lineup: List.of(_seats))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Who's playing?")),
      body: FutureBuilder<List<PlayerProfile>>(
        future: _profiles,
        builder: (context, snapshot) {
          final profiles = snapshot.data;
          if (profiles == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final taken = _seats.whereType<PlayerProfile>().toSet();
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var seat = 0; seat < widget.playerCount; seat++)
                  _SeatRow(
                    seat: seat,
                    profiles: profiles,
                    selected: _seats[seat],
                    taken: taken,
                    onChanged: (p) => _assign(seat, p),
                  ),
                const Spacer(),
                FilledButton(
                  key: const ValueKey('start_match_button'),
                  onPressed: _start,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Start match'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One seat's picker: Guest, or any profile not already taken by another
/// seat. `taken` is every profile assigned anywhere, including this seat's
/// own current pick — a chip is disabled only when it's taken *elsewhere*.
class _SeatRow extends StatelessWidget {
  const _SeatRow({
    required this.seat,
    required this.profiles,
    required this.selected,
    required this.taken,
    required this.onChanged,
  });

  final int seat;
  final List<PlayerProfile> profiles;
  final PlayerProfile? selected;
  final Set<PlayerProfile> taken;
  final ValueChanged<PlayerProfile?> onChanged;

  Widget _chip(String key, String label, PlayerProfile? value) {
    final isSelected = selected == value;
    final isDisabled = value != null && !isSelected && taken.contains(value);
    return ChoiceChip(
      key: ValueKey(key),
      label: Text(label),
      selected: isSelected,
      onSelected: isDisabled ? null : (_) => onChanged(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = SeatPalette.color(seat);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Text('Seat ${seat + 1}', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('seat_${seat}_guest', 'Guest', null),
              for (final profile in profiles)
                _chip('seat_${seat}_${profile.id}', profile.name, profile),
            ],
          ),
        ],
      ),
    );
  }
}
