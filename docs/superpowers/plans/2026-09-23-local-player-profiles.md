# Local Player Profiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the owner create named local player profiles, assign them to seats when starting a match (with friction-free defaults for 0 or 1 profile), and see statistics scoped to one player at a time.

**Architecture:** A new `PlayerProfile` model + `PlayerStorage` service (mirroring the existing `GameResult`/`GameStorage` pair) persist named profiles locally. `GameResult`'s `PlayerScore` gains optional `profileId`/`name` snapshot fields so history keeps parsing unmodified. `Statistics.from` gains an optional `profileId` scope and a `wins` count. `DiceGame` is untouched — identity is threaded through the widget layer only: `GameScreen` takes a `List<PlayerProfile?> lineup` (null = guest seat) instead of a bare `playerCount`, and resolves display names for `ScoreTable`, the turn header, the handoff cover, and `ResultsScreen`.

**Tech Stack:** Flutter (Dart), `shared_preferences` (already a dependency — no new ones).

**Spec:** [docs/superpowers/specs/2026-09-10-local-player-profiles-design.md](../specs/2026-09-10-local-player-profiles-design.md)

## Global Constraints

- No new dependencies. `shared_preferences` is the only non-SDK package — do not add another without asking the author first.
- Small, single-responsibility files — one model/widget/service per file.
- Pure logic stays in `lib/models/` and `lib/services/` with no `package:flutter` import; widgets hold no game rules.
- Test-first: write the failing test before the implementation, for every step below.
- Deterministic tests: `SharedPreferences.setMockInitialValues({})` in `setUp`, per the existing `game_storage_test.dart` / `dice_game_test.dart` pattern.
- Keep `flutter analyze` clean — no new warnings.
- Prefer `const` constructors and immutable data where practical.
- No history migration — every existing `GameResult` entry (no `profileId`/`name` keys) must keep parsing unchanged.
- No per-guest statistics — unassigned seats stay `"Player N"` and only ever roll up into the **Everyone** statistics scope.

---

### Task 1: `PlayerProfile` model

**Files:**
- Create: `lib/models/player_profile.dart`
- Test: `test/player_profile_test.dart`

**Interfaces:**
- Produces: `class PlayerProfile { const PlayerProfile({required String id, required String name}); final String id; final String name; Map<String, dynamic> toJson(); factory PlayerProfile.fromJson(Map<String, dynamic> json); bool operator ==(Object other); int get hashCode; }`

- [ ] **Step 1: Write the failing test**

```dart
// test/player_profile_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:dice_zee/models/player_profile.dart';

void main() {
  test('round-trips through JSON', () {
    const profile = PlayerProfile(id: '123', name: 'Levon');

    final restored = PlayerProfile.fromJson(profile.toJson());

    expect(restored.id, '123');
    expect(restored.name, 'Levon');
  });

  test('equal id and name compare equal', () {
    expect(
      const PlayerProfile(id: '1', name: 'Levon'),
      const PlayerProfile(id: '1', name: 'Levon'),
    );
  });

  test('a different id is not equal', () {
    expect(
      const PlayerProfile(id: '1', name: 'Levon'),
      isNot(const PlayerProfile(id: '2', name: 'Levon')),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/player_profile_test.dart`
Expected: FAIL — `package:dice_zee/models/player_profile.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/models/player_profile.dart
/// A locally-created player: just a stable id and a display name.
class PlayerProfile {
  const PlayerProfile({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory PlayerProfile.fromJson(Map<String, dynamic> json) => PlayerProfile(
        id: json['id'] as String,
        name: json['name'] as String,
      );

  @override
  bool operator ==(Object other) =>
      other is PlayerProfile && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/player_profile_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/models/player_profile.dart test/player_profile_test.dart
git commit -m "$(cat <<'EOF'
Add PlayerProfile model

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `PlayerScore` gains `profileId` and `name`

**Files:**
- Modify: `lib/models/game_result.dart`
- Test: `test/game_result_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `PlayerScore({required Map<ScoreCategory,int> categoryScores, String? profileId, String? name})` with matching `toJson`/`fromJson`; `profileId`/`name` are both `null` on any entry written before this feature.

- [ ] **Step 1: Write the failing test**

Add to `test/game_result_test.dart`, inside `group('PlayerScore', ...)`:

```dart
    test('round-trips profileId and name', () {
      final score = PlayerScore(
        categoryScores: {for (final c in ScoreCategory.values) c: c.index},
        profileId: 'p1',
        name: 'Levon',
      );

      final restored = PlayerScore.fromJson(score.toJson());

      expect(restored.profileId, 'p1');
      expect(restored.name, 'Levon');
    });

    test('a legacy entry with neither key still parses', () {
      final legacy = {for (final c in ScoreCategory.values) c.name: c.index};

      final restored = PlayerScore.fromJson(legacy);

      expect(restored.profileId, isNull);
      expect(restored.name, isNull);
      expect(restored.total, greaterThan(0));
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/game_result_test.dart`
Expected: FAIL — `profileId`/`name` are not defined parameters on `PlayerScore`.

- [ ] **Step 3: Write minimal implementation**

Replace the `PlayerScore` class in `lib/models/game_result.dart`:

```dart
/// One player's finished card: every category's score, plus which local
/// profile (if any) played this seat.
class PlayerScore {
  const PlayerScore({required this.categoryScores, this.profileId, this.name});

  final Map<ScoreCategory, int> categoryScores;

  /// The [PlayerProfile.id] that played this seat, or null for a guest.
  final String? profileId;

  /// A snapshot of the display name at the time the match was played, so
  /// history stays readable after a rename or delete. Null for a guest.
  final String? name;

  int get total => categoryScores.values.fold(0, (a, b) => a + b);

  Map<String, dynamic> toJson() => {
        for (final entry in categoryScores.entries) entry.key.name: entry.value,
        'profileId': profileId,
        'name': name,
      };

  factory PlayerScore.fromJson(Map<String, dynamic> json) => PlayerScore(
        categoryScores: {
          for (final category in ScoreCategory.values)
            category: (json[category.name] as num?)?.toInt() ?? 0,
        },
        profileId: json['profileId'] as String?,
        name: json['name'] as String?,
      );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/game_result_test.dart`
Expected: PASS (all tests, including the two new ones)

- [ ] **Step 5: Commit**

```bash
git add lib/models/game_result.dart test/game_result_test.dart
git commit -m "$(cat <<'EOF'
Add profileId and name to PlayerScore

Legacy history entries (neither key present) still parse, with both
fields null.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: `Statistics` gains profile scoping and `wins`

**Files:**
- Modify: `lib/models/statistics.dart`
- Test: `test/statistics_test.dart`

**Interfaces:**
- Consumes: `PlayerScore.profileId` (Task 2), `GameResult.players`.
- Produces: `Statistics.from(List<GameResult> history, {String? profileId})`; `Statistics.wins` (`int`, 0 when `profileId` is null).

- [ ] **Step 1: Write the failing test**

Add to `test/statistics_test.dart`. First widen the `player` helper (existing calls keep compiling since the new parameter is optional):

```dart
PlayerScore player(Map<ScoreCategory, int> overrides, {String? profileId}) =>
    PlayerScore(
      categoryScores: {
        for (final c in ScoreCategory.values) c: overrides[c] ?? 0,
      },
      profileId: profileId,
    );
```

Then add a new group at the end of `main()`:

```dart
  group('scoped to a profile', () {
    final history = [
      game([
        player({ScoreCategory.sixes: 18, ScoreCategory.yahtzee: 100},
            profileId: 'levon'), // 118, sole winner
        player({ScoreCategory.chance: 20}), // 20, guest
      ]),
      game([
        player({ScoreCategory.fullHouse: 30}, profileId: 'anna'), // 30
        player({ScoreCategory.chance: 30}, profileId: 'levon'), // 30, tie
      ]),
      game([
        player({ScoreCategory.chance: 10}, profileId: 'levon'), // 10
        player({ScoreCategory.chance: 50}, profileId: 'anna'), // 50, winner
      ]),
    ];

    final levon = Statistics.from(history, profileId: 'levon');

    test('games played counts only games this profile appeared in', () {
      expect(levon.gamesPlayed, 3);
    });

    test("average score is scoped to this profile's totals", () {
      // (118 + 30 + 10) / 3
      expect(levon.averageScore, closeTo(52.67, 0.01));
    });

    test('best-by-category is scoped to this profile', () {
      expect(levon.bestByCategory[ScoreCategory.yahtzee], 100);
      expect(levon.bestByCategory[ScoreCategory.chance], 30); // not anna's 50
    });

    test('wins counts strict-highest games only; ties credit nobody', () {
      expect(levon.wins, 1); // game 1 only
    });
  });

  test('Statistics.from with no profileId matches the pre-scoping numbers', () {
    final history = [
      game([
        player({ScoreCategory.sixes: 18}, profileId: 'levon'),
        player({ScoreCategory.chance: 20}),
      ]),
    ];

    final everyone = Statistics.from(history);

    expect(everyone.gamesPlayed, 1);
    expect(everyone.averageScore, 19.0); // (18 + 20) / 2
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/statistics_test.dart`
Expected: FAIL — `Statistics.from` has no `profileId` parameter, `Statistics.wins` is undefined.

- [ ] **Step 3: Write minimal implementation**

Replace `lib/models/statistics.dart`:

```dart
import 'dart:math';

import 'game_result.dart';
import 'score_card.dart';

/// Aggregate figures derived from stored [GameResult]s, optionally scoped to
/// one [PlayerProfile] via its id.
class Statistics {
  Statistics._({
    required this.gamesPlayed,
    required this.averageScore,
    required this.bestByCategory,
    required this.wins,
  });

  /// Games played: total games when unscoped, or games this profile
  /// appeared in when scoped.
  final int gamesPlayed;

  /// Mean of every scoped total across every scoped game; 0 when none.
  final double averageScore;

  /// Highest value ever committed to each category within scope; 0 when
  /// never scored in scope.
  final Map<ScoreCategory, int> bestByCategory;

  /// Games where this profile's seat held the strictly-highest total. Ties
  /// credit nobody. Always 0 when unscoped (profileId == null).
  final int wins;

  /// [profileId] == null aggregates every game ("Everyone"); otherwise only
  /// the slots played by that profile.
  factory Statistics.from(List<GameResult> history, {String? profileId}) {
    final slots = [
      for (final game in history)
        for (final player in game.players)
          if (profileId == null || player.profileId == profileId) player,
    ];

    final totals = [for (final p in slots) p.total];

    final best = {for (final c in ScoreCategory.values) c: 0};
    for (final p in slots) {
      p.categoryScores.forEach((category, score) {
        if (score > best[category]!) best[category] = score;
      });
    }

    var wins = 0;
    if (profileId != null) {
      for (final game in history) {
        final gameTotals = [for (final p in game.players) p.total];
        final bestTotal = gameTotals.reduce(max);
        final leaders = [
          for (var i = 0; i < gameTotals.length; i++)
            if (gameTotals[i] == bestTotal) i,
        ];
        if (leaders.length == 1 &&
            game.players[leaders.single].profileId == profileId) {
          wins++;
        }
      }
    }

    return Statistics._(
      gamesPlayed: profileId == null ? history.length : slots.length,
      averageScore: totals.isEmpty
          ? 0.0
          : totals.reduce((a, b) => a + b) / totals.length,
      bestByCategory: best,
      wins: wins,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/statistics_test.dart`
Expected: PASS (all tests, including the two new groups)

- [ ] **Step 5: Commit**

```bash
git add lib/models/statistics.dart test/statistics_test.dart
git commit -m "$(cat <<'EOF'
Scope Statistics to a profile, add wins

Statistics.from takes an optional profileId; omitted, it behaves
exactly as before ("Everyone"). Wins count strict-highest games only
— a tie credits nobody, matching DiceGame.winner.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: `PlayerStorage` service

**Files:**
- Create: `lib/services/player_storage.dart`
- Test: `test/player_storage_test.dart`

**Interfaces:**
- Consumes: `PlayerProfile` (Task 1).
- Produces: `class PlayerStorage { const PlayerStorage(); Future<List<PlayerProfile>> loadProfiles(); Future<void> addProfile(String name); Future<void> renameProfile(String id, String name); Future<void> deleteProfile(String id); }`

- [ ] **Step 1: Write the failing test**

```dart
// test/player_storage_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dice_zee/services/player_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  const storage = PlayerStorage();

  test('loadProfiles is empty when nothing has been saved', () async {
    expect(await storage.loadProfiles(), isEmpty);
  });

  test('addProfile appends a new profile with a generated id', () async {
    await storage.addProfile('Levon');

    final profiles = await storage.loadProfiles();
    expect(profiles, hasLength(1));
    expect(profiles.single.name, 'Levon');
    expect(profiles.single.id, isNotEmpty);
  });

  test('addProfile preserves insertion order', () async {
    await storage.addProfile('Levon');
    await storage.addProfile('Anna');

    final names = (await storage.loadProfiles()).map((p) => p.name).toList();
    expect(names, ['Levon', 'Anna']);
  });

  test('renameProfile updates only the matching profile', () async {
    await storage.addProfile('Levon');
    await storage.addProfile('Anna');
    final id = (await storage.loadProfiles()).first.id;

    await storage.renameProfile(id, 'Levon E.');

    final names = (await storage.loadProfiles()).map((p) => p.name).toList();
    expect(names, ['Levon E.', 'Anna']);
  });

  test('renameProfile is a no-op for an unknown id', () async {
    await storage.addProfile('Levon');

    await storage.renameProfile('missing', 'X');

    final names = (await storage.loadProfiles()).map((p) => p.name).toList();
    expect(names, ['Levon']);
  });

  test('deleteProfile removes only the matching profile', () async {
    await storage.addProfile('Levon');
    await storage.addProfile('Anna');
    final id = (await storage.loadProfiles()).first.id;

    await storage.deleteProfile(id);

    final names = (await storage.loadProfiles()).map((p) => p.name).toList();
    expect(names, ['Anna']);
  });

  test('unparseable legacy entries are skipped, not thrown', () async {
    SharedPreferences.setMockInitialValues({
      'dice_zee.players': jsonEncode([
        {'foo': 'bar'}, // bad shape
        {'id': '1', 'name': 'Levon'},
      ]),
    });

    final profiles = await storage.loadProfiles();
    expect(profiles, hasLength(1));
    expect(profiles.single.name, 'Levon');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/player_storage_test.dart`
Expected: FAIL — `package:dice_zee/services/player_storage.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/services/player_storage.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/player_profile.dart';

/// Local persistence for player profiles, backed by [SharedPreferences].
///
/// All profiles live under one key as a JSON array, in add order.
class PlayerStorage {
  const PlayerStorage();

  static const String _profilesKey = 'dice_zee.players';

  /// Every stored [PlayerProfile], in the order they were added.
  Future<List<PlayerProfile>> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profilesKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return [
      for (final entry in decoded)
        if (_tryParse(entry) case final PlayerProfile profile) profile,
    ];
  }

  /// Parse one stored entry, or null if it is not a current-shape
  /// [PlayerProfile].
  static PlayerProfile? _tryParse(dynamic entry) {
    try {
      return PlayerProfile.fromJson(entry as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveProfiles(List<PlayerProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(profiles.map((p) => p.toJson()).toList());
    await prefs.setString(_profilesKey, encoded);
  }

  /// Append a new profile named [name] with a freshly generated id.
  Future<void> addProfile(String name) async {
    final profiles = await loadProfiles();
    profiles.add(PlayerProfile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
    ));
    await _saveProfiles(profiles);
  }

  /// Rename the profile with id [id] to [name]. No-op if not found.
  Future<void> renameProfile(String id, String name) async {
    final profiles = await loadProfiles();
    final index = profiles.indexWhere((p) => p.id == id);
    if (index == -1) return;
    profiles[index] = PlayerProfile(id: id, name: name);
    await _saveProfiles(profiles);
  }

  /// Remove the profile with id [id]. No-op if not found.
  Future<void> deleteProfile(String id) async {
    final profiles = await loadProfiles();
    profiles.removeWhere((p) => p.id == id);
    await _saveProfiles(profiles);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/player_storage_test.dart`
Expected: PASS (7 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/services/player_storage.dart test/player_storage_test.dart
git commit -m "$(cat <<'EOF'
Add PlayerStorage service

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: `ScoreTable` and `ResultsScreen` accept resolved names

**Files:**
- Modify: `lib/widgets/score_table.dart`
- Modify: `lib/widgets/results_screen.dart`
- Test: `test/widgets/score_table_test.dart`
- Create: `test/widgets/results_screen_test.dart`

**Interfaces:**
- Consumes: nothing new (still `SeatPalette` for colours and the fallback label).
- Produces: `ScoreTable(..., List<String>? names)` — `names[p]` overrides the column header, falling back to `SeatPalette.shortLabel(p)`. `ResultsScreen(..., List<String>? names)` — `names[seat]` overrides the winner banner and each standing row, falling back to `SeatPalette.label(seat)`.

- [ ] **Step 1: Write the failing tests**

Add to `test/widgets/score_table_test.dart` (any position inside `main()`):

```dart
  testWidgets('uses provided names in the column header when given',
      (tester) async {
    await tester.pumpWidget(_host(ScoreTable(
      cards: cards(2),
      currentPlayer: 0,
      currentDice: const [1, 2, 3, 4, 5],
      canCommit: false,
      onCommit: (_) {},
      names: const ['Levon', 'Anna'],
    )));

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('col_header_0')),
        matching: find.text('Levon'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('falls back to short seat labels when no names are given',
      (tester) async {
    await tester.pumpWidget(_host(ScoreTable(
      cards: cards(2),
      currentPlayer: 0,
      currentDice: const [1, 2, 3, 4, 5],
      canCommit: false,
      onCommit: (_) {},
    )));

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('col_header_0')),
        matching: find.text('P1'),
      ),
      findsOneWidget,
    );
  });
```

Create `test/widgets/results_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dice_zee/widgets/results_screen.dart';

void main() {
  testWidgets('falls back to seat labels when no names are given',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ResultsScreen(standings: [30, 45], winner: 1),
    ));

    expect(find.text('Player 2 wins!'), findsOneWidget);
    expect(find.text('Player 1'), findsOneWidget);
  });

  testWidgets('uses provided names when given', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ResultsScreen(
        standings: [30, 45],
        winner: 1,
        names: ['Levon', 'Anna'],
      ),
    ));

    expect(find.text('Anna wins!'), findsOneWidget);
    expect(find.text('Levon'), findsOneWidget);
  });

  testWidgets('Rematch pops ResultsAction.rematch', (tester) async {
    ResultsAction? popped;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            popped = await Navigator.of(context).push<ResultsAction>(
              MaterialPageRoute(
                builder: (_) =>
                    const ResultsScreen(standings: [30, 45], winner: 1),
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rematch_button')));
    await tester.pumpAndSettle();

    expect(popped, ResultsAction.rematch);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widgets/score_table_test.dart test/widgets/results_screen_test.dart`
Expected: FAIL — `names` is not a parameter of `ScoreTable` or `ResultsScreen`.

- [ ] **Step 3: Write minimal implementation**

In `lib/widgets/score_table.dart`, add the field and use it in `_headerRow`:

```dart
  const ScoreTable({
    super.key,
    required this.cards,
    required this.currentPlayer,
    required this.currentDice,
    required this.canCommit,
    required this.onCommit,
    this.names,
  });

  final List<ScoreCard> cards;
  final int currentPlayer;
  final List<int> currentDice;
  final bool canCommit;
  final ValueChanged<ScoreCategory> onCommit;

  /// Resolved display name per seat; falls back to [SeatPalette.shortLabel].
  final List<String>? names;
```

```dart
  TableRow _headerRow(BuildContext context) {
    final theme = Theme.of(context);
    final seat = _seatColor();
    return TableRow(
      children: [
        const SizedBox(height: 40),
        for (var p = 0; p < cards.length; p++)
          _Cell(
            key: ValueKey('col_header_$p'),
            highlightColor:
                p == currentPlayer ? seat.withValues(alpha: 0.14) : null,
            child: Text(
              names?[p] ?? SeatPalette.shortLabel(p),
              style: theme.textTheme.labelLarge?.copyWith(
                color: p == currentPlayer ? seat : null,
                fontWeight:
                    p == currentPlayer ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
      ],
    );
  }
```

In `lib/widgets/results_screen.dart`:

```dart
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/widgets/score_table_test.dart test/widgets/results_screen_test.dart`
Expected: PASS (all tests, old and new)

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/score_table.dart lib/widgets/results_screen.dart \
        test/widgets/score_table_test.dart test/widgets/results_screen_test.dart
git commit -m "$(cat <<'EOF'
Let ScoreTable and ResultsScreen accept resolved player names

Both fall back to the existing SeatPalette labels when no names are
given, so every current call site keeps working unmodified.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: `GameScreen` takes a `lineup` instead of a bare `playerCount`

**Files:**
- Modify: `lib/widgets/game_screen.dart`
- Test: `test/widgets/game_screen_test.dart`

**Interfaces:**
- Consumes: `PlayerProfile` (Task 1), `ScoreTable.names` / `ResultsScreen.names` (Task 5), `PlayerScore.profileId`/`.name` (Task 2).
- Produces: `GameScreen({required List<PlayerProfile?> lineup, GameStorage storage, Random? random})`. `lineup.length` is the player count; a `null` entry is a guest seat.

- [ ] **Step 1: Write the failing test**

Update `test/widgets/game_screen_test.dart`:

```dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dice_zee/models/player_profile.dart';
import 'package:dice_zee/models/score_card.dart';
import 'package:dice_zee/services/game_storage.dart';
import 'package:dice_zee/widgets/game_screen.dart';
import 'package:dice_zee/widgets/results_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget subject({int playerCount = 2, List<PlayerProfile?>? lineup}) =>
      MaterialApp(
        home: GameScreen(
          lineup: lineup ?? List<PlayerProfile?>.filled(playerCount, null),
          storage: const GameStorage(),
          random: Random(1),
        ),
      );

  /// A tall viewport so the whole screen fits without scrolling.
  Future<void> pumpTall(
    WidgetTester tester, {
    int playerCount = 2,
    List<PlayerProfile?>? lineup,
  }) async {
    await tester.binding.setSurfaceSize(const Size(900, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(subject(playerCount: playerCount, lineup: lineup));
  }

  final rollButton = find.byKey(const ValueKey('roll_button'));
  final handoffReady = find.byKey(const ValueKey('handoff_ready'));

  Future<void> rollAndCommit(WidgetTester tester, ScoreCategory category) async {
    await tester.tap(rollButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('commit_${category.name}')));
    await tester.pumpAndSettle();
    if (handoffReady.evaluate().isNotEmpty) {
      await tester.tap(handoffReady);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('opens on player 1, round 1, with 3 rolls', (tester) async {
    await tester.pumpWidget(subject());

    expect(find.text('Player 1'), findsOneWidget);
    expect(find.text('Round 1 / 15'), findsOneWidget);
    expect(find.bySemanticsLabel('3 rolls left'), findsOneWidget);
  });

  testWidgets('no category is committable until the first roll', (tester) async {
    await tester.pumpWidget(subject());

    expect(find.byKey(const ValueKey('commit_chance')), findsNothing);
    expect(find.text('Player 1'), findsOneWidget);
  });

  testWidgets('rolling spends a roll', (tester) async {
    await tester.pumpWidget(subject());

    await tester.tap(rollButton);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('2 rolls left'), findsOneWidget);
  });

  testWidgets('committing shows a handoff cover, then the next turn',
      (tester) async {
    await pumpTall(tester);

    await tester.tap(rollButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('commit_chance')));
    await tester.pumpAndSettle();

    // The next player is behind a handoff cover until they tap "Start turn".
    expect(find.byKey(const ValueKey('handoff_seat')), findsOneWidget);
    await tester.tap(handoffReady);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('handoff_seat')), findsNothing);
    expect(find.text('Player 2'), findsOneWidget);
    expect(find.text('Round 1 / 15'), findsOneWidget);
    expect(find.bySemanticsLabel('3 rolls left'), findsOneWidget);
  });

  testWidgets('lays out on a phone-sized screen with 4 players, no overflow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(subject(playerCount: 4));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('roll_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('total_3')), findsOneWidget);
  });

  testWidgets('every player total is visible in the shared table',
      (tester) async {
    await pumpTall(tester, playerCount: 3);

    expect(find.byKey(const ValueKey('total_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('total_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('total_2')), findsOneWidget);
  });

  testWidgets("a seated profile's name replaces the seat's default label",
      (tester) async {
    const levon = PlayerProfile(id: '1', name: 'Levon');
    await tester.pumpWidget(subject(lineup: const [levon, null]));

    expect(find.text('Levon'), findsOneWidget);
    expect(find.text('Player 1'), findsNothing);
  });

  testWidgets('finishing the match saves a result and shows the results screen',
      (tester) async {
    await pumpTall(tester);

    for (final category in ScoreCategory.values) {
      for (var player = 0; player < 2; player++) {
        await rollAndCommit(tester, category);
      }
    }

    expect(find.byType(ResultsScreen), findsOneWidget);
    expect(find.text('Rematch'), findsOneWidget);

    final history = await const GameStorage().loadHistory();
    expect(history, hasLength(1));
    expect(history.single.playerCount, 2);
  });

  testWidgets("finishing the match records each seat's profile id and name",
      (tester) async {
    const levon = PlayerProfile(id: 'p1', name: 'Levon');
    await pumpTall(tester, lineup: const [levon, null]);

    for (final category in ScoreCategory.values) {
      for (var player = 0; player < 2; player++) {
        await rollAndCommit(tester, category);
      }
    }

    final history = await const GameStorage().loadHistory();
    expect(history.single.players[0].profileId, 'p1');
    expect(history.single.players[0].name, 'Levon');
    expect(history.single.players[1].profileId, isNull);
    expect(history.single.players[1].name, isNull);
  });

  testWidgets('Rematch from the results screen starts a fresh match',
      (tester) async {
    await pumpTall(tester);

    for (final category in ScoreCategory.values) {
      for (var player = 0; player < 2; player++) {
        await rollAndCommit(tester, category);
      }
    }

    await tester.tap(find.byKey(const ValueKey('rematch_button')));
    await tester.pumpAndSettle();

    expect(find.byType(ResultsScreen), findsNothing);
    expect(find.text('Player 1'), findsOneWidget);
    expect(find.text('Round 1 / 15'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/game_screen_test.dart`
Expected: FAIL — `GameScreen` has no `lineup` parameter (compile error).

- [ ] **Step 3: Write minimal implementation**

Replace the top of `lib/widgets/game_screen.dart` through `_GameScreenState`'s `_buildResult`/`_showResults`, and the `_TurnHeader`/`_HandoffCover` classes:

```dart
import 'dart:math';

import 'package:flutter/material.dart';

import '../haptics.dart';
import '../models/dice_game.dart';
import '../models/game_result.dart';
import '../models/player_profile.dart';
import '../models/score_card.dart';
import '../seat_palette.dart';
import '../services/game_storage.dart';
import 'dice_row.dart';
import 'results_screen.dart';
import 'score_table.dart';

/// The playing screen for a 2–4 player hot-seat match. Owns one [DiceGame] and
/// rebuilds on every action.
///
/// Layout is three zones: a fixed turn header, the scrolling shared score
/// table, and a pinned control deck (dice + Roll) in the thumb zone. Between
/// turns a full-screen handoff cover asks the next player to get ready.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.lineup,
    this.storage = const GameStorage(),
    this.random,
  });

  /// One entry per seat, in turn order. A null entry is a guest seat and
  /// falls back to [SeatPalette.label].
  final List<PlayerProfile?> lineup;

  final GameStorage storage;

  /// Seed source for the dice; injected in tests for determinism.
  final Random? random;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final DiceGame _game = DiceGame(
    playerCount: widget.lineup.length,
    random: widget.random,
  );
  int _rollCount = 0;
  bool _summaryShown = false;
  bool _awaitingHandoff = false;

  String _nameFor(int seat) => widget.lineup[seat]?.name ?? SeatPalette.label(seat);

  List<String> get _names =>
      [for (var p = 0; p < _game.playerCount; p++) _nameFor(p)];

  void _roll() {
    AppHaptics.roll();
    setState(() {
      _game.roll();
      _rollCount++;
    });
  }

  void _toggleHold(int index) {
    AppHaptics.hold();
    setState(() => _game.toggleHold(index));
  }

  Future<void> _commit(ScoreCategory category) async {
    AppHaptics.commit();
    setState(() {
      _game.commitScore(category);
      _rollCount++;
    });

    if (_game.isOver) {
      if (!_summaryShown) {
        _summaryShown = true;
        AppHaptics.gameOver();
        await widget.storage.saveResult(_buildResult());
        if (mounted) await _showResults();
      }
      return;
    }

    AppHaptics.hold();
    setState(() => _awaitingHandoff = true);
  }

  GameResult _buildResult() => GameResult(
        playedAt: DateTime.now(),
        playerCount: _game.playerCount,
        players: [
          for (var p = 0; p < _game.playerCount; p++)
            PlayerScore(
              categoryScores: {
                for (final c in ScoreCategory.values)
                  c: _game.scoreCardFor(p).scoreOf(c) ?? 0,
              },
              profileId: widget.lineup[p]?.id,
              name: widget.lineup[p]?.name,
            ),
        ],
      );

  Future<void> _showResults() async {
    final action = await Navigator.of(context).push<ResultsAction>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ResultsScreen(
          standings: _game.standings,
          winner: _game.winner,
          names: _names,
        ),
      ),
    );
    if (!mounted) return;

    if (action == ResultsAction.rematch) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => GameScreen(
            lineup: widget.lineup,
            storage: widget.storage,
          ),
        ),
      );
    } else {
      Navigator.of(context).pop(); // back to the menu
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seat = _game.currentPlayer;
    final seatColor = SeatPalette.color(seat);
    final canRoll = _game.rollsRemaining > 0 && !_game.isOver;
    final canAct = _game.hasRolledThisRound && !_game.isOver;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dice Zee'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Round ${_game.round.clamp(1, 15)} / 15',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _TurnHeader(
                seat: seat,
                name: _nameFor(seat),
                color: seatColor,
                rollsRemaining: _game.rollsRemaining,
              ),
              Expanded(
                child: Scrollbar(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    child: ScoreTable(
                      cards: _game.scoreCards,
                      currentPlayer: seat,
                      currentDice: _game.dice,
                      canCommit: canAct,
                      onCommit: _commit,
                      names: _names,
                    ),
                  ),
                ),
              ),
              _ControlDeck(
                dice: _game.dice,
                held: _game.held,
                canHold: canAct,
                placeholder: !_game.hasRolledThisRound,
                rollCount: _rollCount,
                seatColor: seatColor,
                rollsRemaining: _game.rollsRemaining,
                canRoll: canRoll,
                awaitingCommit: !canRoll && canAct,
                onRoll: _roll,
                onToggleHold: _toggleHold,
              ),
            ],
          ),
          if (_awaitingHandoff)
            _HandoffCover(
              seat: seat,
              name: _nameFor(seat),
              color: seatColor,
              onReady: () => setState(() => _awaitingHandoff = false),
            ),
        ],
      ),
    );
  }
}

/// Whose turn it is, and how many rolls they have left (as pips).
class _TurnHeader extends StatelessWidget {
  const _TurnHeader({
    required this.seat,
    required this.name,
    required this.color,
    required this.rollsRemaining,
  });

  final int seat;
  final String name;
  final Color color;
  final int rollsRemaining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: color.withValues(alpha: 0.10),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(
            name,
            key: const ValueKey('turn_header'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          _RollsPips(remaining: rollsRemaining, color: color),
        ],
      ),
    );
  }
}
```

Leave `_RollsPips` and `_ControlDeck` unchanged. Update `_HandoffCover`:

```dart
/// Full-screen "pass the phone" cover shown between turns.
class _HandoffCover extends StatelessWidget {
  const _HandoffCover({
    required this.seat,
    required this.name,
    required this.color,
    required this.onReady,
  });

  final int seat;
  final String name;
  final Color color;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: Material(
        color: color.withValues(alpha: 0.97),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.front_hand, size: 56, color: Colors.white),
                const SizedBox(height: 24),
                Text(
                  'Pass the phone to',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  key: const ValueKey('handoff_seat'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 40),
                FilledButton(
                  key: const ValueKey('handoff_ready'),
                  onPressed: onReady,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: color,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Start turn'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

(`_RollsPips` and `_ControlDeck` bodies are copied verbatim from the current file — no changes.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/game_screen_test.dart`
Expected: PASS (all tests, including the two new ones)

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/game_screen.dart test/widgets/game_screen_test.dart
git commit -m "$(cat <<'EOF'
Thread player profiles through GameScreen as a lineup

GameScreen now takes lineup: List<PlayerProfile?> instead of a bare
playerCount. A null entry is a guest seat and falls back to
SeatPalette.label. Finished results record each seat's profileId and
a snapshot of its name.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: `PlayerSelectScreen`

**Files:**
- Create: `lib/widgets/player_select_screen.dart`
- Test: `test/widgets/player_select_screen_test.dart`

**Interfaces:**
- Consumes: `PlayerProfile`, `PlayerStorage.loadProfiles` (Task 4), `GameScreen(lineup: ...)` (Task 6).
- Produces: `PlayerSelectScreen({required int playerCount, PlayerStorage storage})` — pushes `GameScreen` (replacing itself) with the chosen `List<PlayerProfile?>` on "Start match".

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/player_select_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dice_zee/services/player_storage.dart';
import 'package:dice_zee/widgets/game_screen.dart';
import 'package:dice_zee/widgets/player_select_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storage = PlayerStorage();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget subject(int playerCount) => MaterialApp(
        home: PlayerSelectScreen(playerCount: playerCount, storage: storage),
      );

  testWidgets('every seat defaults to Guest', (tester) async {
    await storage.addProfile('Levon');
    await storage.addProfile('Anna');

    await tester.pumpWidget(subject(2));
    await tester.pumpAndSettle();

    final guest0 =
        tester.widget<ChoiceChip>(find.byKey(const ValueKey('seat_0_guest')));
    final guest1 =
        tester.widget<ChoiceChip>(find.byKey(const ValueKey('seat_1_guest')));
    expect(guest0.selected, isTrue);
    expect(guest1.selected, isTrue);
  });

  testWidgets('picking a profile for one seat disables it on the other seats',
      (tester) async {
    await storage.addProfile('Levon');
    await storage.addProfile('Anna');
    final levon = (await storage.loadProfiles())[0];

    await tester.pumpWidget(subject(2));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('seat_0_${levon.id}')));
    await tester.pumpAndSettle();

    final seat0Chip =
        tester.widget<ChoiceChip>(find.byKey(ValueKey('seat_0_${levon.id}')));
    expect(seat0Chip.selected, isTrue);

    final seat1Chip =
        tester.widget<ChoiceChip>(find.byKey(ValueKey('seat_1_${levon.id}')));
    expect(seat1Chip.onSelected, isNull); // disabled: taken by seat 0
  });

  testWidgets('Start match opens the game with the chosen lineup',
      (tester) async {
    await storage.addProfile('Levon');
    await storage.addProfile('Anna');
    final levon = (await storage.loadProfiles())[0];

    await tester.pumpWidget(subject(2));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('seat_0_${levon.id}')));
    await tester.pumpAndSettle();
    // Seat 1 stays Guest.
    await tester.tap(find.byKey(const ValueKey('start_match_button')));
    await tester.pumpAndSettle();

    final game = tester.widget<GameScreen>(find.byType(GameScreen));
    expect(game.lineup, [levon, null]);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/player_select_screen_test.dart`
Expected: FAIL — `package:dice_zee/widgets/player_select_screen.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/widgets/player_select_screen.dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/player_select_screen_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/player_select_screen.dart test/widgets/player_select_screen_test.dart
git commit -m "$(cat <<'EOF'
Add PlayerSelectScreen

Shown only when 2+ profiles are registered: a Guest/profile chip row
per seat, a profile disabled elsewhere once picked for one seat, Start
match hands the chosen lineup to GameScreen.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: `PlayersScreen` (add / rename / delete)

**Files:**
- Create: `lib/widgets/players_screen.dart`
- Test: `test/widgets/players_screen_test.dart`

**Interfaces:**
- Consumes: `PlayerProfile`, `PlayerStorage` (Task 4).
- Produces: `class PlayersScreen extends StatefulWidget { const PlayersScreen({PlayerStorage storage}); }`.

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/players_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dice_zee/services/player_storage.dart';
import 'package:dice_zee/widgets/players_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storage = PlayerStorage();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget subject() => const MaterialApp(home: PlayersScreen(storage: storage));

  testWidgets('shows an empty state with no profiles', (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.text('No players yet.'), findsOneWidget);
  });

  testWidgets('adding a player shows it in the list', (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add_player_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('player_name_field')),
      'Levon',
    );
    await tester.tap(find.byKey(const ValueKey('save_player_name')));
    await tester.pumpAndSettle();

    expect(find.text('Levon'), findsOneWidget);
    expect(await storage.loadProfiles(), hasLength(1));
  });

  testWidgets('tapping a player renames it', (tester) async {
    await storage.addProfile('Levon');

    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Levon'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('player_name_field')),
      'Levon E.',
    );
    await tester.tap(find.byKey(const ValueKey('save_player_name')));
    await tester.pumpAndSettle();

    expect(find.text('Levon E.'), findsOneWidget);
    expect(find.text('Levon'), findsNothing);
  });

  testWidgets('deleting a player removes it after confirming', (tester) async {
    await storage.addProfile('Levon');
    final id = (await storage.loadProfiles()).single.id;

    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('delete_$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.text('Levon'), findsNothing);
    expect(await storage.loadProfiles(), isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/players_screen_test.dart`
Expected: FAIL — `package:dice_zee/widgets/players_screen.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/widgets/players_screen.dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/players_screen_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/players_screen.dart test/widgets/players_screen_test.dart
git commit -m "$(cat <<'EOF'
Add PlayersScreen for add/rename/delete of local profiles

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: `PlayerStatsScreen` (scoped detail, extracted from the old `StatisticsScreen` body)

**Files:**
- Create: `lib/widgets/player_stats_screen.dart`
- Test: `test/widgets/player_stats_screen_test.dart`

**Interfaces:**
- Consumes: `Statistics.from(history, {profileId})` (Task 3).
- Produces: `class PlayerStatsScreen extends StatefulWidget { const PlayerStatsScreen({required String title, String? profileId, GameStorage storage}); }`.

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/player_stats_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dice_zee/models/game_result.dart';
import 'package:dice_zee/models/score_card.dart';
import 'package:dice_zee/services/game_storage.dart';
import 'package:dice_zee/widgets/player_stats_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  const storage = GameStorage();

  testWidgets('shows an empty state when no games have been played',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: PlayerStatsScreen(title: 'Everyone', storage: storage),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No games played yet.'), findsOneWidget);
  });

  testWidgets('Everyone shows Games played and Average score, no Wins card',
      (tester) async {
    await storage.saveResult(GameResult(
      playedAt: DateTime.utc(2026, 9, 7),
      playerCount: 2,
      players: [
        PlayerScore(categoryScores: {
          for (final c in ScoreCategory.values) c: 0,
          ScoreCategory.yahtzee: 100,
        }),
        PlayerScore(categoryScores: {
          for (final c in ScoreCategory.values) c: 0,
          ScoreCategory.sixes: 30,
        }),
      ],
    ));

    await tester.binding.setSurfaceSize(const Size(800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(
      home: PlayerStatsScreen(title: 'Everyone', storage: storage),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('stat_games')), findsOneWidget);
    expect(find.byKey(const ValueKey('stat_avg')), findsOneWidget);
    expect(find.byKey(const ValueKey('stat_wins')), findsNothing);
  });

  testWidgets('a profile shows a Wins card scoped to its own games',
      (tester) async {
    await storage.saveResult(GameResult(
      playedAt: DateTime.utc(2026, 9, 7),
      playerCount: 2,
      players: [
        PlayerScore(
          categoryScores: {
            for (final c in ScoreCategory.values) c: 0,
            ScoreCategory.yahtzee: 100,
          },
          profileId: 'levon',
        ), // winner
        PlayerScore(categoryScores: {
          for (final c in ScoreCategory.values) c: 0,
          ScoreCategory.sixes: 30,
        }),
      ],
    ));

    await tester.binding.setSurfaceSize(const Size(800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(
      home: PlayerStatsScreen(
        title: 'Levon',
        profileId: 'levon',
        storage: storage,
      ),
    ));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('stat_wins')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/player_stats_screen_test.dart`
Expected: FAIL — `package:dice_zee/widgets/player_stats_screen.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/widgets/player_stats_screen.dart
import 'package:flutter/material.dart';

import '../models/statistics.dart';
import '../services/game_storage.dart';
import 'bottom_padding.dart';
import 'score_table.dart';

/// One player's (or "Everyone"'s) stats, scoped via [profileId].
class PlayerStatsScreen extends StatefulWidget {
  const PlayerStatsScreen({
    super.key,
    required this.title,
    this.profileId,
    this.storage = const GameStorage(),
  });

  /// App-bar title: a profile's name, or "Everyone".
  final String title;

  /// Scope stats to this profile; null means every game ("Everyone").
  final String? profileId;

  final GameStorage storage;

  @override
  State<PlayerStatsScreen> createState() => _PlayerStatsScreenState();
}

class _PlayerStatsScreenState extends State<PlayerStatsScreen> {
  late final Future<Statistics> _stats = widget.storage
      .loadHistory()
      .then((history) => Statistics.from(history, profileId: widget.profileId));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<Statistics>(
        future: _stats,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stats = snapshot.data!;
          if (stats.gamesPlayed == 0) {
            return const _EmptyState();
          }
          return _StatsBody(stats: stats, showWins: widget.profileId != null);
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

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.stats, required this.showWins});

  final Statistics stats;

  /// Show a Wins card (per-profile view only — meaningless for "Everyone").
  final bool showWins;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, BottomPadding.of(context)),
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                statKey: 'stat_games',
                value: '${stats.gamesPlayed}',
                label: 'Games played',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: showWins
                  ? _StatCard(
                      statKey: 'stat_wins',
                      value: '${stats.wins}',
                      label: 'Wins',
                    )
                  : _StatCard(
                      statKey: 'stat_avg',
                      value: stats.averageScore.toStringAsFixed(1),
                      label: 'Average score',
                    ),
            ),
          ],
        ),
        if (showWins) ...[
          const SizedBox(height: 12),
          _StatCard(
            statKey: 'stat_avg',
            value: stats.averageScore.toStringAsFixed(1),
            label: 'Average score',
          ),
        ],
        const SizedBox(height: 24),
        Text('Best ever by category', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.6,
          children: [
            for (final entry in stats.bestByCategory.entries)
              _BestTile(
                tileKey: 'best_${entry.key.name}',
                label: categoryLabel(entry.key),
                value: entry.value,
              ),
          ],
        ),
      ],
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
  });

  final String tileKey;
  final String label;
  final int value;

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
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/player_stats_screen_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/player_stats_screen.dart test/widgets/player_stats_screen_test.dart
git commit -m "$(cat <<'EOF'
Add PlayerStatsScreen, scoped stats detail

Extracted from the old StatisticsScreen body. Everyone keeps today's
Games played + Average score pair; a profile view adds a Wins card.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 10: `StatisticsScreen` becomes the Everyone + per-profile list

**Files:**
- Modify: `lib/widgets/statistics_screen.dart`
- Test: `test/widgets/statistics_screen_test.dart`

**Interfaces:**
- Consumes: `PlayerStorage.loadProfiles` (Task 4), `Statistics.from` (Task 3), `PlayerStatsScreen` (Task 9).
- Produces: `StatisticsScreen({GameStorage storage, PlayerStorage playerStorage})` — a list: an "Everyone" row, then one row per profile, each pushing `PlayerStatsScreen`.

- [ ] **Step 1: Write the failing test**

Replace `test/widgets/statistics_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dice_zee/models/game_result.dart';
import 'package:dice_zee/models/score_card.dart';
import 'package:dice_zee/services/game_storage.dart';
import 'package:dice_zee/services/player_storage.dart';
import 'package:dice_zee/widgets/player_stats_screen.dart';
import 'package:dice_zee/widgets/statistics_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  const storage = GameStorage();
  const playerStorage = PlayerStorage();

  Widget subject() => const MaterialApp(
        home: StatisticsScreen(storage: storage, playerStorage: playerStorage),
      );

  testWidgets('always lists an Everyone row', (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('stats_everyone')), findsOneWidget);
    expect(find.text('0 games'), findsOneWidget);
  });

  testWidgets('lists one row per registered profile', (tester) async {
    await playerStorage.addProfile('Levon');
    await playerStorage.addProfile('Anna');

    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.text('Levon'), findsOneWidget);
    expect(find.text('Anna'), findsOneWidget);
  });

  testWidgets("a profile row shows its own game and win counts",
      (tester) async {
    await playerStorage.addProfile('Levon');
    final levon = (await playerStorage.loadProfiles()).single;

    await storage.saveResult(GameResult(
      playedAt: DateTime.utc(2026, 9, 7),
      playerCount: 2,
      players: [
        PlayerScore(
          categoryScores: {
            for (final c in ScoreCategory.values) c: 0,
            ScoreCategory.yahtzee: 100,
          },
          profileId: levon.id,
          name: levon.name,
        ), // total 100, winner
        PlayerScore(categoryScores: {
          for (final c in ScoreCategory.values) c: 0,
          ScoreCategory.sixes: 30,
        }), // total 30, guest
      ],
    ));

    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.text('1 games · 1 wins'), findsOneWidget);
  });

  testWidgets('tapping Everyone opens its detail screen', (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('stats_everyone')));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerStatsScreen), findsOneWidget);
    expect(find.text('No games played yet.'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/statistics_screen_test.dart`
Expected: FAIL — `StatisticsScreen` has no `playerStorage` parameter; `stats_everyone` key does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/widgets/statistics_screen.dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/statistics_screen_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/statistics_screen.dart test/widgets/statistics_screen_test.dart
git commit -m "$(cat <<'EOF'
Rework StatisticsScreen into an Everyone + per-profile list

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 11: Wire it up in `MainMenuScreen`

**Files:**
- Modify: `lib/widgets/main_menu.dart`
- Test: `test/widgets/main_menu_test.dart`

**Interfaces:**
- Consumes: `PlayerStorage.loadProfiles` (Task 4), `PlayerSelectScreen` (Task 7), `PlayersScreen` (Task 8), `GameScreen(lineup: ...)` (Task 6).
- Produces: `MainMenuScreen({GameStorage storage, PlayerStorage playerStorage})`. Start branches: 0 profiles → all-guest lineup; 1 profile → that profile seated first, rest guests; 2+ → push `PlayerSelectScreen`. A new **Players** button opens `PlayersScreen`.

- [ ] **Step 1: Write the failing test**

Replace `test/widgets/main_menu_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dice_zee/services/player_storage.dart';
import 'package:dice_zee/widgets/game_screen.dart';
import 'package:dice_zee/widgets/main_menu.dart';
import 'package:dice_zee/widgets/player_select_screen.dart';
import 'package:dice_zee/widgets/players_screen.dart';
import 'package:dice_zee/widgets/statistics_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('offers a 2, 3 and 4 player choice', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(SegmentedButton<int>, '2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.byKey(const ValueKey('start_button')), findsOneWidget);
  });

  testWidgets(
      'starting with no profiles registered opens the game with an all-guest lineup',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('3'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('start_button')));
    await tester.pumpAndSettle();

    final screen = tester.widget<GameScreen>(find.byType(GameScreen));
    expect(screen.lineup, [null, null, null]);
  });

  testWidgets(
      'starting with exactly one profile seats it first, no selection screen',
      (tester) async {
    const playerStorage = PlayerStorage();
    await playerStorage.addProfile('Levon');
    final levon = (await playerStorage.loadProfiles()).single;

    await tester.pumpWidget(const MaterialApp(
      home: MainMenuScreen(playerStorage: playerStorage),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start_button')));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerSelectScreen), findsNothing);
    final screen = tester.widget<GameScreen>(find.byType(GameScreen));
    expect(screen.lineup, [levon, null]);
  });

  testWidgets('starting with 2+ profiles opens the player select screen',
      (tester) async {
    const playerStorage = PlayerStorage();
    await playerStorage.addProfile('Levon');
    await playerStorage.addProfile('Anna');

    await tester.pumpWidget(const MaterialApp(
      home: MainMenuScreen(playerStorage: playerStorage),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('start_button')));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerSelectScreen), findsOneWidget);
  });

  testWidgets('the statistics button opens the statistics screen',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Statistics'));
    await tester.pumpAndSettle();

    expect(find.byType(StatisticsScreen), findsOneWidget);
  });

  testWidgets('the players button opens the players screen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainMenuScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Players'));
    await tester.pumpAndSettle();

    expect(find.byType(PlayersScreen), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/main_menu_test.dart`
Expected: FAIL — `MainMenuScreen` has no `playerStorage` parameter; no "Players" button; `GameScreen.playerCount` no longer exists (compile error from the old usage still present).

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/widgets/main_menu.dart
import 'package:flutter/material.dart';

import '../models/game_result.dart';
import '../models/player_profile.dart';
import '../services/game_storage.dart';
import '../services/player_storage.dart';
import 'game_screen.dart';
import 'pip_face.dart';
import 'player_select_screen.dart';
import 'players_screen.dart';
import 'statistics_screen.dart';
import 'version_indicator.dart';

/// App home: pick a player count and start a match, manage players, or view
/// statistics.
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({
    super.key,
    this.storage = const GameStorage(),
    this.playerStorage = const PlayerStorage(),
  });

  final GameStorage storage;
  final PlayerStorage playerStorage;

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  int _count = 2;
  late final Future<List<GameResult>> _history = widget.storage.loadHistory();

  Future<void> _startGame() async {
    final profiles = await widget.playerStorage.loadProfiles();
    if (!mounted) return;

    if (profiles.isEmpty) {
      _openGame(List<PlayerProfile?>.filled(_count, null));
      return;
    }
    if (profiles.length == 1) {
      _openGame([profiles.single, for (var i = 1; i < _count; i++) null]);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerSelectScreen(playerCount: _count),
      ),
    );
  }

  void _openGame(List<PlayerProfile?> lineup) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameScreen(lineup: lineup)),
    );
  }

  void _openStatistics() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StatisticsScreen()),
    );
  }

  void _openPlayers() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PlayersScreen()),
    );
  }

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
                  _BestGameLine(history: _history),
                  const SizedBox(height: 40),
                  Text(
                    'Players',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 2, label: Text('2')),
                        ButtonSegment(value: 3, label: Text('3')),
                        ButtonSegment(value: 4, label: Text('4')),
                      ],
                      selected: {_count},
                      onSelectionChanged: (s) =>
                          setState(() => _count = s.first),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const ValueKey('start_button'),
                    onPressed: _startGame,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('Start'),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _openStatistics,
                    icon: const Icon(Icons.bar_chart),
                    label: const Text('Statistics'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _openPlayers,
                    icon: const Icon(Icons.people_outline),
                    label: const Text('Players'),
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

/// "Best game · N" once at least one match has been recorded; nothing before.
class _BestGameLine extends StatelessWidget {
  const _BestGameLine({required this.history});

  final Future<List<GameResult>> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<GameResult>>(
      future: history,
      builder: (context, snapshot) {
        final games = snapshot.data;
        if (games == null || games.isEmpty) return const SizedBox.shrink();
        final best = games
            .expand((g) => g.players.map((p) => p.total))
            .fold(0, (a, b) => a > b ? a : b);
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            'Best game · $best',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );
      },
    );
  }
}
```

(Only `_startGame`, the new `_openGame`/`_openPlayers` methods, the constructor, the imports, and the extra "Players" button are new — everything else is unchanged from the current file.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/main_menu_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/main_menu.dart test/widgets/main_menu_test.dart
git commit -m "$(cat <<'EOF'
Wire player profiles into the main menu

Start branches on registered profile count: 0 -> all-guest lineup,
1 -> that profile seated first (rest guests), 2+ -> PlayerSelectScreen.
Adds a Players button to reach PlayersScreen.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 12: Full suite + analyzer sweep

**Files:** none (verification only).

- [ ] **Step 1: Run the full test suite**

Run: `flutter test`
Expected: PASS — every test file in `test/`, old and new.

- [ ] **Step 2: Run the analyzer**

Run: `flutter analyze`
Expected: `No issues found!` (no new warnings beyond whatever the branch already had before this plan).

- [ ] **Step 3: Fix anything the sweep turns up**

If either command reports a problem, fix it in the relevant file from Tasks 1–11, re-run both commands, and repeat until both are clean.

- [ ] **Step 4: Commit (only if Step 3 changed anything)**

```bash
git add -A
git commit -m "$(cat <<'EOF'
Fix analyzer/test issues found in the full-suite sweep

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```
