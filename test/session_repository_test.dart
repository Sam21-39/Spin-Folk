import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spinfolk/core/failure.dart';
import 'package:spinfolk/features/history/data/history_repository_impl.dart';
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
    expect(Sqflite.firstIntValue(await db.rawQuery('PRAGMA user_version')), 2);
    final t = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    expect(
      t.map((r) => r['name']),
      containsAll([
        'session',
        'player',
        'round_log',
        'game',
        'game_player',
        'game_round',
      ]),
    );
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
    await repo.saveRound(s, log: s.log.last);
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

  test('saveRound with invalid log entry rolls back', () async {
    final s = await repo.start(ps(8));
    final next = s.revealed(const Outcome(taker: 1, giver: 5));
    for (final bad in const [
      RoundEntry(round: 1, taker: 2, giver: 2, result: RoundResult.truth),
      RoundEntry(round: 0, taker: 1, giver: 5, result: RoundResult.truth),
    ]) {
      await expectLater(
        repo.saveRound(next, log: bad),
        throwsA(isA<StorageFailure>()),
      );
      final l = (await repo.load())!;
      expect(l.phase, Phase.ready);
      expect(l.round, 1);
      expect(await count('round_log'), 0);
    }
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

  test('end without rounds cascades and archives nothing', () async {
    final s = await repo.start(ps(8));
    expect(await repo.end(s), isNull);
    expect(await count('session'), 0);
    expect(await count('player'), 0);
    expect(await count('game'), 0);
  });

  /// Plays [rounds] logged rounds on a fresh session; returns it.
  Future<Session> play(int rounds, {int n = 8}) async {
    var s = await repo.start(ps(n, {1: 'Riya'}));
    for (var i = 0; i < rounds; i++) {
      s = s.revealed(const Outcome(taker: 1, giver: 5));
      await repo.saveRound(s);
      s = s.chose(i.isEven ? Mode.truth : Mode.dare);
      await repo.saveRound(s, log: s.log.last);
      s = s.nextRound();
      await repo.saveRound(s);
    }
    return s;
  }

  group('round log', () {
    test('saveRound with log writes a row; same round replaces it', () async {
      var s = await repo.start(ps(8));
      s = s.revealed(const Outcome(taker: 1, giver: 5)).chose(Mode.truth);
      await repo.saveRound(s, log: s.log.last);
      expect(await count('round_log'), 1);
      expect(await repo.load(), s);
      s = s.passed();
      await repo.saveRound(s, log: s.log.last);
      expect(await count('round_log'), 1);
      final l = (await repo.load())!;
      expect(l.log.single.result, RoundResult.pass);
      expect(l, s);
    });

    test('unknown session id writes nothing', () async {
      await repo.start(ps(3));
      final s = Session(
        id: 'nope',
        startedAtMs: 0,
        players: ps(3),
      ).revealed(const Outcome(taker: 0, giver: 1)).chose(Mode.dare);
      await expectLater(
        repo.saveRound(s, log: s.log.last),
        throwsA(isA<StorageFailure>()),
      );
      expect(await count('round_log'), 0);
    });
  });

  group('archive', () {
    test('end with rounds fills game tables, empties session', () async {
      final s = await play(3);
      final rec = (await repo.end(s))!;
      expect(rec.rounds, hasLength(3));
      expect(await count('session'), 0);
      expect(await count('player'), 0);
      expect(await count('round_log'), 0);
      expect(await count('game'), 1);
      expect(await count('game_player'), 8);
      expect(await count('game_round'), 3);
      final games = await HistoryRepositoryImpl(db).games();
      expect(games.single, rec);
      expect(games.single.players, s.players);
      expect(games.single.rounds, s.log);
      expect(rec.endedAtMs, greaterThanOrEqualTo(rec.startedAtMs));
    });

    test('start over a stored session with rounds archives it', () async {
      final old = await play(2);
      final fresh = await repo.start(ps(4));
      expect(fresh.id, isNot(old.id));
      expect(await count('game'), 1);
      expect(await count('game_round'), 2);
      expect(await count('round_log'), 0);
      expect(await count('session'), 1);
      expect((await repo.load())!.playerCount, 4);
    });

    test('start over a session without rounds archives nothing', () async {
      await repo.start(ps(4));
      await repo.start(ps(3));
      expect(await count('game'), 0);
    });
  });

  group('v2 CHECKs', () {
    test('result, taker = giver, ended_at < started_at', () async {
      final s = await repo.start(ps(8));
      for (final row in [
        {'round': 1, 'taker': 0, 'giver': 1, 'result': 'x'},
        {'round': 1, 'taker': 2, 'giver': 2, 'result': 'pass'},
      ]) {
        await expectLater(
          db.insert('round_log', {'session_id': s.id, ...row}),
          throwsA(isA<DatabaseException>()),
        );
      }
      await expectLater(
        db.insert('game', {
          'id': 'g',
          'started_at': 10,
          'ended_at': 9,
          'player_count': 4,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('file database', () {
    late Directory dir;
    late String path;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('spinfolk_db');
      addTearDown(() => dir.delete(recursive: true));
      path = '${dir.path}/t.db';
    });

    test('v1 file migrates to v2 with data intact', () async {
      final v1 = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
          onCreate: (d, _) async {
            for (final sql in sessionSchema) {
              await d.execute(sql);
            }
          },
        ),
      );
      await v1.insert('session', {
        'id': 'old',
        'started_at': 5,
        'player_count': 3,
        'round': 2,
        'phase': 'ready',
      });
      for (var i = 0; i < 3; i++) {
        await v1.insert('player', {
          'session_id': 'old',
          'seat': i,
          'name': i == 0 ? 'Riya' : null,
        });
      }
      await v1.close();

      final v2 = await openSessionDb(factory: databaseFactoryFfi, path: path);
      addTearDown(v2.close);
      expect(
        Sqflite.firstIntValue(await v2.rawQuery('PRAGMA user_version')),
        2,
      );
      final t = await v2.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      expect(
        t.map((r) => r['name']),
        containsAll(['round_log', 'game', 'game_player', 'game_round']),
      );
      final s = (await SessionRepositoryImpl(v2).load())!;
      expect(s.id, 'old');
      expect(s.round, 2);
      expect(s.players, ps(3, {0: 'Riya'}));
      expect(s.log, isEmpty);
    });

    test('soft-deleted games are purged at reopen', () async {
      var d = await openSessionDb(factory: databaseFactoryFfi, path: path);
      final r = SessionRepositoryImpl(d);
      final h = HistoryRepositoryImpl(d);
      var s = await r.start(ps(4));
      s = s.revealed(const Outcome(taker: 0, giver: 2)).chose(Mode.truth);
      await r.saveRound(s, log: s.log.last);
      final rec = (await r.end(s))!;
      await h.softDelete([rec.id], 1);
      expect(await h.games(), isEmpty);
      await d.close();
      d = await openSessionDb(factory: databaseFactoryFfi, path: path);
      addTearDown(d.close);
      for (final t in ['game', 'game_player', 'game_round']) {
        expect(
          Sqflite.firstIntValue(await d.rawQuery('SELECT count(*) FROM $t')),
          0,
          reason: t,
        );
      }
    });
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
