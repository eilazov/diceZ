import 'dart:async';

import 'package:flutter/material.dart';

import '../models/game_result.dart';
import '../models/game_mode.dart';
import '../models/player_profile.dart';
import '../services/auth_service.dart';
import '../services/game_storage.dart';
import '../services/player_storage.dart';
import '../services/sync_service.dart';
import 'account_screen.dart';
import 'online_hub_screen.dart';
import 'pip_face.dart';
import 'play_menu_screen.dart';
import 'statistics_screen.dart';
import 'version_indicator.dart';

/// App home: play, go online, view statistics, or open the account.
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({
    super.key,
    this.storage = const GameStorage(),
    this.playerStorage = const PlayerStorage(),
    this.authServiceBuilder,
  });

  final GameStorage storage;
  final PlayerStorage playerStorage;

  /// Builds the auth service lazily (Firebase is only touched once the
  /// Account screen opens). Defaults to [FirebaseAuthService].
  final AuthService Function()? authServiceBuilder;

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  late Future<_BestData> _best = _loadBest();
  StreamSubscription<void>? _syncSub;

  /// Match history plus the signed-in account's profile (null as a guest).
  Future<_BestData> _loadBest() async {
    final history = await widget.storage.loadHistory();
    final profiles = await widget.playerStorage.loadProfiles();
    return (history, profiles.where((p) => p.linkedToAccount).firstOrNull);
  }

  /// Opens [screen]; whatever it saved or changed (games, sign-in) shows up in
  /// the best scores when it closes.
  void _push(Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .then((_) {
          if (mounted) setState(() => _best = _loadBest());
        });
  }

  @override
  void initState() {
    super.initState();
    // A cloud pull may bring in matches from other devices.
    _syncSub = SyncService.instance.changes.listen((_) {
      if (mounted) setState(() => _best = _loadBest());
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  void _openPlay() =>
      _push(PlayMenuScreen(playerStorage: widget.playerStorage));

  void _openOnline() =>
      _push(OnlineHubScreen(authService: widget.authServiceBuilder?.call()));

  void _openStatistics() => _push(const StatisticsScreen());

  void _openAccount() =>
      _push(AccountScreen(authService: widget.authServiceBuilder?.call()));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      PipFace(
                        value: 5,
                        color: theme.colorScheme.primary,
                        size: 44,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Dice Zee',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  _BestGameLine(best: _best),
                  const SizedBox(height: 40),
                  FilledButton.icon(
                    key: const ValueKey('online_button'),
                    onPressed: _openOnline,
                    icon: const Icon(Icons.casino),
                    label: const Text('Play'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    key: const ValueKey('offline_button'),
                    onPressed: _openPlay,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('Offline Game'),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _openStatistics,
                    icon: const Icon(Icons.bar_chart),
                    label: const Text('Statistics'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _openAccount,
                    icon: const Icon(Icons.account_circle_outlined),
                    label: const Text('Account'),
                  ),
                  const SizedBox(height: 24),
                  const VersionIndicator(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

typedef _BestData = (List<GameResult>, PlayerProfile?);

/// "Standard best · N" for each mode in which the signed-in account has a
/// result; nothing for guests or modes it hasn't played.
class _BestGameLine extends StatelessWidget {
  const _BestGameLine({required this.best});

  final Future<_BestData> best;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<_BestData>(
      future: best,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final account = data?.$2;
        if (data == null || account == null) return const SizedBox.shrink();
        final games = data.$1;
        return Column(
          children: [
            for (final mode in GameMode.values)
              if (_best(games, mode, account.id) case final int score)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    '${mode.label} best · $score',
                    key: ValueKey('best_${mode.name}'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }

  /// The account's highest total in [mode], or null if it has none.
  static int? _best(List<GameResult> games, GameMode mode, String profileId) {
    final totals = [
      for (final g in games)
        if (g.mode == mode)
          for (final p in g.players)
            if (p.profileId == profileId) p.total,
    ];
    return totals.isEmpty ? null : totals.reduce((a, b) => a > b ? a : b);
  }
}
