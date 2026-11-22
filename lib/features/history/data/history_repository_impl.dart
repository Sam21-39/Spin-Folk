import 'package:injectable/injectable.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/failure.dart';
import '../../session/domain/entities/game_record.dart';
import '../../session/domain/entities/session.dart';
import '../domain/history_repository.dart';

@LazySingleton(as: HistoryRepository)
class HistoryRepositoryImpl implements HistoryRepository {
  HistoryRepositoryImpl(this._db);
  final Database _db;

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DatabaseException catch (_) {
      throw const StorageFailure();
    }
  }

  @override
  // ponytail: loads the whole history; page it if it ever exceeds a few hundred games.
  Future<List<GameRecord>> games() => _guard(() async {
    final games = await _db.query(
      'game',
      where: 'deleted_at IS NULL',
      orderBy: 'ended_at DESC',
    );
    final players = await _db.query('game_player', orderBy: 'game_id, seat');
    final rounds = await _db.query('game_round', orderBy: 'game_id, round');
    final p = <String, List<Player>>{};
    for (final r in players) {
      (p[r['game_id']! as String] ??= []).add(
        Player(seat: r['seat']! as int, name: r['name'] as String?),
      );
    }
    final e = <String, List<RoundEntry>>{};
    for (final r in rounds) {
      (e[r['game_id']! as String] ??= []).add(
        RoundEntry(
          round: r['round']! as int,
          taker: r['taker']! as int,
          giver: r['giver']! as int,
          result: RoundResult.values.byName(r['result']! as String),
        ),
      );
    }
    return [
      for (final g in games)
        GameRecord(
          id: g['id']! as String,
          startedAtMs: g['started_at']! as int,
          endedAtMs: g['ended_at']! as int,
          players: p[g['id']] ?? const [],
          rounds: e[g['id']] ?? const [],
        ),
    ];
  });

  @override
  Future<void> softDelete(List<String> ids, int atMs) => _guard(() async {
    if (ids.isEmpty) return;
    await _db.rawUpdate(
      'UPDATE game SET deleted_at = ? WHERE id IN (${_marks(ids)})',
      [atMs, ...ids],
    );
  });

  @override
  Future<void> restore(List<String> ids) => _guard(() async {
    if (ids.isEmpty) return;
    await _db.rawUpdate(
      'UPDATE game SET deleted_at = NULL WHERE id IN (${_marks(ids)})',
      ids,
    );
  });

  @override
  Future<void> purgeDeleted() =>
      _guard(() => _db.delete('game', where: 'deleted_at IS NOT NULL'));

  String _marks(List<String> ids) => List.filled(ids.length, '?').join(',');
}
