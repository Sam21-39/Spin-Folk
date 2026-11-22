import 'dart:async';

import 'package:spinfolk/core/failure.dart';
import 'package:spinfolk/features/session/domain/entities/game_record.dart';
import 'package:spinfolk/features/session/domain/entities/session.dart';
import 'package:spinfolk/features/session/domain/session_repository.dart';

import 'fake_history_repository.dart';

class FakeSessionRepository implements SessionRepository {
  FakeSessionRepository([this.history]);

  /// End and start-over archive into this, like the real repository.
  FakeHistoryRepository? history;
  Session? stored;
  Object? loadError;
  bool failWrites = false;
  final List<String> calls = [];
  Completer<void>? saveGate;
  int _started = 0;

  void _write(String name) {
    calls.add(name);
    if (failWrites) throw const StorageFailure();
  }

  /// Null (and nothing archived) when the session has no logged round.
  GameRecord? _archive(Session s) {
    if (s.log.isEmpty) return null;
    final g = GameRecord(
      id: s.id,
      startedAtMs: s.startedAtMs,
      endedAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      players: s.players,
      rounds: s.log,
    );
    history?.add(g);
    return g;
  }

  @override
  Future<Session?> load() async {
    calls.add('load');
    final e = loadError;
    if (e != null) throw e;
    return stored;
  }

  @override
  Future<Session> start(List<Player> players) async {
    _write('start');
    final old = stored;
    if (old != null) _archive(old);
    // 'test' for the first fresh start; ids stay unique inside History.
    final id = _started++ == 0 && old?.id != 'test' ? 'test' : 'test$_started';
    return stored = Session(id: id, startedAtMs: 0, players: players);
  }

  @override
  Future<void> saveRound(Session session, {RoundEntry? log}) async {
    _write('saveRound');
    await saveGate?.future;
    stored = session;
  }

  @override
  Future<void> replacePlayers(String id, List<Player> players) async {
    _write('replacePlayers');
    stored = stored!.withPlayers(players);
  }

  @override
  Future<GameRecord?> end(Session session) async {
    _write('end');
    stored = null;
    return _archive(session);
  }
}
