import 'dart:math';

import 'package:injectable/injectable.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/failure.dart';
import '../domain/entities/session.dart';
import '../domain/session_repository.dart';

@LazySingleton(as: SessionRepository)
class SessionRepositoryImpl implements SessionRepository {
  SessionRepositoryImpl(this._db);
  final Database _db;

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DatabaseException catch (_) {
      throw const StorageFailure();
    }
  }

  @override
  Future<Session?> load() => _guard(() async {
    final rows = await _db.query('session');
    if (rows.isEmpty) return null;
    final players = await _db.query('player', orderBy: 'seat');
    Session? s;
    try {
      final r = rows.single;
      final taker = r['taker'] as int?;
      s = Session(
        id: r['id']! as String,
        startedAtMs: r['started_at']! as int,
        round: r['round']! as int,
        phase: Phase.values.byName(r['phase']! as String),
        outcome: taker == null
            ? null
            : Outcome(taker: taker, giver: r['giver']! as int),
        mode: switch (r['mode']) {
          final String m => Mode.values.byName(m),
          _ => null,
        },
        players: [
          for (final p in players)
            Player(seat: p['seat']! as int, name: p['name'] as String?),
        ],
      );
      if (r['player_count'] != players.length || !s.isValid) s = null;
    } on ArgumentError {
      s = null;
    } on TypeError {
      s = null;
    }
    if (s == null) {
      await _db.delete('session');
      throw const CorruptSession();
    }
    return s;
  });

  @override
  Future<Session> start(List<Player> players) => _guard(() async {
    final rng = Random.secure();
    final id = [
      for (var i = 0; i < 16; i++)
        rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    final session = Session(
      id: id,
      startedAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      players: players,
    );
    await _db.transaction((txn) async {
      await txn.delete('session');
      await txn.insert('session', {
        'id': id,
        'started_at': session.startedAtMs,
        'player_count': players.length,
        'round': 1,
        'phase': Phase.ready.name,
      });
      await _insertPlayers(txn, id, players);
    });
    return session;
  });

  @override
  Future<void> saveRound(Session s) => _guard(() async {
    final n = await _db.update(
      'session',
      {
        'round': s.round,
        'phase': s.phase.name,
        'taker': s.outcome?.taker,
        'giver': s.outcome?.giver,
        'mode': s.mode?.name,
      },
      where: 'id = ?',
      whereArgs: [s.id],
    );
    if (n != 1) throw const StorageFailure();
  });

  @override
  Future<void> replacePlayers(String id, List<Player> players) => _guard(
    () => _db.transaction((txn) async {
      final n = await txn.update(
        'session',
        {'player_count': players.length},
        where: 'id = ?',
        whereArgs: [id],
      );
      if (n != 1) throw const StorageFailure(); // rolls the transaction back
      await txn.delete('player', where: 'session_id = ?', whereArgs: [id]);
      await _insertPlayers(txn, id, players);
    }),
  );

  @override
  Future<void> end() => _guard(() => _db.delete('session'));

  Future<void> _insertPlayers(
    DatabaseExecutor ex,
    String id,
    List<Player> players,
  ) async {
    final batch = ex.batch();
    for (final p in players) {
      batch.insert('player', {
        'session_id': id,
        'seat': p.seat,
        'name': p.name,
      });
    }
    await batch.commit(noResult: true);
  }
}
