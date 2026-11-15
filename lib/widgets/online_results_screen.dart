import 'package:flutter/material.dart';

import '../models/online_match.dart';
import '../services/online_match_service.dart';
import 'results_screen.dart';

/// End of an online match. Rematch needs both players: the first to tap waits
/// for the other, and once both have asked the new match opens for both. Pops
/// with the new match's id (a String) for a rematch, or a [ResultsAction].
class OnlineResultsScreen extends StatefulWidget {
  const OnlineResultsScreen({
    super.key,
    required this.match,
    required this.uid,
    required this.service,
  });

  /// The finished match as it was when the results opened.
  final OnlineMatch match;
  final String uid;
  final OnlineMatchService service;

  @override
  State<OnlineResultsScreen> createState() => _OnlineResultsScreenState();
}

class _OnlineResultsScreenState extends State<OnlineResultsScreen> {
  late final Stream<OnlineMatch?> _stream = widget.service.watch(
    widget.match.id,
  );
  bool _starting = false;
  bool _left = false;

  /// Starts the new match when it is this player's job, and leaves for it as
  /// soon as it exists.
  Future<void> _advance(OnlineMatch match) async {
    final next = match.rematchMatchId;
    if (next != null) {
      if (!_left && mounted) {
        _left = true;
        Navigator.of(context).pop(next);
      }
      return;
    }
    if (_starting) return;
    _starting = true;
    try {
      await widget.service.startRematchIfReady(match, widget.uid);
    } catch (_) {
      // The stream re-delivers; the other player's device may start it.
    } finally {
      _starting = false;
    }
  }

  Future<void> _vote() async {
    try {
      await widget.service.voteRematch(widget.match, widget.uid);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't ask for a rematch. Try again."),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<OnlineMatch?>(
      stream: _stream,
      initialData: widget.match,
      builder: (context, snapshot) {
        final match = snapshot.data ?? widget.match;
        WidgetsBinding.instance.addPostFrameCallback((_) => _advance(match));

        final game = match.game();
        final mySeat = match.seatOf(widget.uid) ?? 0;
        final opponent = match.names[1 - mySeat];
        final iAsked = match.rematch.contains(widget.uid);
        final theyAsked = match.rematch.any((u) => u != widget.uid);
        return ResultsScreen(
          standings: game.standings,
          winner: game.winner,
          names: match.names,
          onRematch: _vote,
          rematchEnabled: !iAsked,
          rematchLabel: iAsked
              ? 'Waiting for $opponent…'
              : theyAsked
              ? 'Rematch · $opponent is ready'
              : 'Rematch',
        );
      },
    );
  }
}
