import 'package:flutter_test/flutter_test.dart';
import 'package:spinfolk/core/failure.dart';
import 'package:spinfolk/features/session/data/session_db.dart';
import 'package:spinfolk/features/session/data/session_repository_impl.dart';
import 'package:spinfolk/features/session/domain/entities/session.dart';
import 'package:sqflite/sqflite.dart' show Sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

List<Player> ps(int n, [Map<int, String> names = const {}]) => [
  for (var i = 0; i < n; i++) Player(seat: i, name: names[i]),
];

void main() {
  setUpAll(sqfliteFfiInit);

  late Database db;
  late SessionRepositoryImpl repo;

  setUp(() async {
    db = await openSessionDb(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repo = SessionRepositoryImpl(db);
  });
  tearDown(() => db.close());

  Future<int> count(String t) async =>
      Sqflite.firstIntValue(await db.rawQuery('SELECT count(*) FROM $t'))!;

  test('schema, pragmas', () async {
    expect(Sqflite.firstIntValue(await db.rawQuery('PRAGMA foreign_keys')), 1);
    expect(Sqflite.firstIntValue(await db.rawQuery('PRAGMA user_version')), 1);
    final t = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    expect(t.map((r) => r['name']), containsAll(['session', 'player']));
  });

  test('load on empty is null', () async {
    expect(await repo.load(), isNull);
  });

  test('start/load round trip', () async {
    final s = await repo.start(ps(5, {1: 'Riya', 4: 'Sam'}));
    expect(s.id, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(s.round, 1);
    expect(s.phase, Phase.ready);
    expect(await repo.load(), s);
    final u = await repo.start(ps(3));
    expect(await repo.load(), u);
  });

  test('start twice keeps one session', () async {
    await repo.start(ps(8));
    final s = await repo.start(ps(3));
    expect(await count('session'), 1);
    expect(await count('player'), 3);
    expect((await repo.load())!.id, s.id);
  });

  test('saveRound transitions', () async {
    var s = await repo.start(ps(8));
    s = s.revealed(const Outcome(taker: 1, giver: 5));
    await repo.saveRound(s);
    expect(await repo.load(), s);
    s = s.chose(Mode.dare);
    await repo.saveRound(s);
    expect(await repo.load(), s);
    s = s.nextRound();
    await repo.saveRound(s);
    expect(await repo.load(), s);
    expect(s.round, 2);
  });

  test('saveRound unknown id fails', () async {
    final s = Session(id: 'nope', startedAtMs: 0, players: ps(3));
    expect(() => repo.saveRound(s), throwsA(isA<StorageFailure>()));
  });

  test('saveRound taker out of range fails via guard', () async {
    final s = await repo.start(ps(3));
    final bad = s.revealed(const Outcome(taker: 3, giver: 0));
    await expectLater(repo.saveRound(bad), throwsA(isA<StorageFailure>()));
    expect((await repo.load())!.phase, Phase.ready);
  });

  test('replacePlayers', () async {
    final s = await repo.start(ps(8));
    await repo.replacePlayers(s.id, ps(5, {0: 'A'}));
    var l = (await repo.load())!;
    expect(l.id, s.id);
    expect(l.players, ps(5, {0: 'A'}));
    await repo.replacePlayers(s.id, ps(60));
    l = (await repo.load())!;
    expect(l.playerCount, 60);
    expect(await count('player'), 60);
    expect(
      () => repo.replacePlayers('nope', ps(3)),
      throwsA(isA<StorageFailure>()),
    );
  });

  test('end cascades', () async {
    await repo.start(ps(8));
    await repo.end();
    expect(await count('session'), 0);
    expect(await count('player'), 0);
  });

  group('schema refuses', () {
    Future<void> insert(Map<String, Object?> over) => db.insert('session', {
      'id': 'a',
      'started_at': 0,
      'player_count': 8,
      'round': 1,
      'phase': 'ready',
      ...over,
    });
    void refuses(String name, Map<String, Object?> over) => test(
      name,
      () => expectLater(insert(over), throwsA(isA<DatabaseException>())),
    );

    refuses('spinning', {'phase': 'spinning'});
    refuses('revealed without taker', {'phase': 'revealed'});
    refuses('taker == giver', {'phase': 'revealed', 'taker': 1, 'giver': 1});
    refuses('taker == player_count', {
      'phase': 'revealed',
      'taker': 8,
      'giver': 1,
    });
    refuses('player_count 1', {'player_count': 1});
    refuses('player_count 61', {'player_count': 61});

    test('second session row', () async {
      await insert({});
      await expectLater(insert({'id': 'b'}), throwsA(isA<DatabaseException>()));
    });

    test('player seat 60, long and empty name', () async {
      await insert({});
      for (final row in [
        {'seat': 60, 'name': null},
        {'seat': 0, 'name': 'x' * 41},
        {'seat': 0, 'name': ''},
      ]) {
        await expectLater(
          db.insert('player', {'session_id': 'a', ...row}),
          throwsA(isA<DatabaseException>()),
        );
      }
    });
  });

  group('corrupt data', () {
    test('missing player row', () async {
      final s = await repo.start(ps(8));
      await db.delete(
        'player',
        where: 'session_id = ? AND seat = 1',
        whereArgs: [s.id],
      );
      await expectLater(repo.load(), throwsA(isA<CorruptSession>()));
      expect(await count('session'), 0);
      expect(await count('player'), 0);
    });

    test('non-opposite pair', () async {
      final s = await repo.start(ps(8));
      await db.update('session', {'phase': 'revealed', 'taker': 0, 'giver': 3});
      expect(s.playerCount, 8);
      await expectLater(repo.load(), throwsA(isA<CorruptSession>()));
      expect(await count('session'), 0);
      expect(await count('player'), 0);
    });
  });
}
