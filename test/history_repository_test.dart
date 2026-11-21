import 'package:flutter_test/flutter_test.dart';
import 'package:spinfolk/features/history/data/history_repository_impl.dart';
import 'package:spinfolk/features/session/data/session_db.dart';
import 'package:spinfolk/features/session/data/session_repository_impl.dart';
import 'package:spinfolk/features/session/domain/entities/game_record.dart';
import 'package:spinfolk/features/session/domain/entities/session.dart';
import 'package:sqflite/sqflite.dart' show Sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Database db;
  late SessionRepositoryImpl sessions;
  late HistoryRepositoryImpl repo;

  setUp(() async {
    db = await openSessionDb(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    sessions = SessionRepositoryImpl(db);
    repo = HistoryRepositoryImpl(db);
  });
  tearDown(() => db.close());

  Future<GameRecord> archive(int n, {String? name}) async {
    var s = await sessions.start([
      for (var i = 0; i < n; i++) Player(seat: i, name: i == 0 ? name : null),
    ]);
    s = s.revealed(const Outcome(taker: 0, giver: 1)).chose(Mode.dare);
    await sessions.saveRound(s, log: s.log.last);
    await Future<void>.delayed(const Duration(milliseconds: 3));
    return (await sessions.end(s))!;
  }

  Future<int> count(String t) async =>
      Sqflite.firstIntValue(await db.rawQuery('SELECT count(*) FROM $t'))!;

  test('newest first, players and rounds attached to the right game', () async {
    final a = await archive(2, name: 'Riya');
    final b = await archive(3);
    final games = await repo.games();
    expect(games.map((g) => g.id), [b.id, a.id]);
    expect(games[0].players, hasLength(3));
    expect(games[1].players.first.name, 'Riya');
    expect(games[0].rounds, hasLength(1));
    expect(games[1].rounds.single.result, RoundResult.dare);
  });

  test('softDelete hides, restore shows', () async {
    final a = await archive(2);
    final b = await archive(2);
    await repo.softDelete([a.id], 5);
    expect((await repo.games()).map((g) => g.id), [b.id]);
    await repo.restore([a.id]);
    expect(await repo.games(), hasLength(2));
  });

  test('empty id lists are no-ops', () async {
    await archive(2);
    await repo.softDelete([], 1);
    await repo.restore([]);
    expect(await repo.games(), hasLength(1));
  });

  test('purgeDeleted removes only soft-deleted rows and cascades', () async {
    final a = await archive(2);
    await archive(4);
    await repo.softDelete([a.id], 5);
    await repo.purgeDeleted();
    expect(await count('game'), 1);
    expect(await count('game_player'), 4);
    expect(await count('game_round'), 1);
  });
}
