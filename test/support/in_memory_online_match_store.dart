import 'dart:async';

import 'package:dice_zee/models/online_match.dart';
import 'package:dice_zee/services/online_match_store.dart';

class InMemoryOnlineMatchStore implements OnlineMatchStore {
  final matches = <String, OnlineMatch>{};
  final _changes = StreamController<void>.broadcast();
  int _next = 1;

  @override
  Future<String> create(OnlineMatch match) async {
    final id = 'm${_next++}';
    matches[id] = match.copyWith(id: id);
    _changes.add(null);
    return id;
  }

  @override
  Future<OnlineMatch?> get(String id) async => matches[id];

  @override
  Stream<OnlineMatch?> watch(String id) async* {
    yield matches[id];
    await for (final _ in _changes.stream) {
      yield matches[id];
    }
  }

  @override
  Stream<List<OnlineMatch>> watchFor(String uid) async* {
    List<OnlineMatch> now() => [
      for (final m in matches.values)
        if (m.players.contains(uid)) m,
    ];
    yield now();
    await for (final _ in _changes.stream) {
      yield now();
    }
  }

  @override
  Future<void> update(OnlineMatch match) async {
    matches[match.id] = match;
    _changes.add(null);
  }

  @override
  Future<void> addRematchVote(String id, String uid) async {
    final m = matches[id]!;
    if (!m.rematch.contains(uid)) {
      matches[id] = m.copyWith(rematch: [...m.rematch, uid]);
    }
    _changes.add(null);
  }

  @override
  Future<void> setRematchMatch(String id, String newMatchId) async {
    matches[id] = matches[id]!.copyWith(rematchMatchId: newMatchId);
    _changes.add(null);
  }

  @override
  Future<void> delete(String id) async {
    matches.remove(id);
    _changes.add(null);
  }
}
