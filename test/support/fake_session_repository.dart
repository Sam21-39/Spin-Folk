import 'dart:async';

import 'package:spinfolk/core/failure.dart';
import 'package:spinfolk/features/session/domain/entities/session.dart';
import 'package:spinfolk/features/session/domain/session_repository.dart';

class FakeSessionRepository implements SessionRepository {
  Session? stored;
  Object? loadError;
  bool failWrites = false;
  final List<String> calls = [];
  Completer<void>? saveGate;

  void _write(String name) {
    calls.add(name);
    if (failWrites) throw const StorageFailure();
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
    return stored = Session(id: 'test', startedAtMs: 0, players: players);
  }

  @override
  Future<void> saveRound(Session session) async {
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
  Future<void> end() async {
    _write('end');
    stored = null;
  }
}
