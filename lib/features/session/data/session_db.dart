import 'dart:io';

import 'package:sqflite/sqflite.dart';

const int sessionDbVersion = 2;

/// Spec A6, verbatim (comments dropped).
const List<String> sessionSchema = [
  '''
CREATE TABLE session (
  id          TEXT    PRIMARY KEY,
  singleton   INTEGER NOT NULL DEFAULT 1 UNIQUE CHECK (singleton = 1),
  started_at  INTEGER NOT NULL,
  player_count INTEGER NOT NULL CHECK (player_count BETWEEN 2 AND 60),
  round       INTEGER NOT NULL CHECK (round >= 1),
  phase       TEXT    NOT NULL CHECK (phase IN ('ready','revealed','challenge')),
  taker       INTEGER,
  giver       INTEGER,
  mode        TEXT    CHECK (mode IN ('truth','dare')),
  CHECK (
    (phase = 'ready'     AND taker IS NULL AND giver IS NULL AND mode IS NULL) OR
    (phase = 'revealed'  AND taker IS NOT NULL AND giver IS NOT NULL AND mode IS NULL) OR
    (phase = 'challenge' AND taker IS NOT NULL AND giver IS NOT NULL AND mode IS NOT NULL)
  ),
  CHECK (taker IS NULL OR (taker BETWEEN 0 AND player_count - 1)),
  CHECK (giver IS NULL OR (giver BETWEEN 0 AND player_count - 1)),
  CHECK (taker IS NULL OR taker <> giver)
)''',
  '''
CREATE TABLE player (
  session_id TEXT    NOT NULL REFERENCES session(id) ON DELETE CASCADE,
  seat       INTEGER NOT NULL CHECK (seat BETWEEN 0 AND 59),
  name       TEXT    CHECK (name IS NULL OR length(name) BETWEEN 1 AND 40),
  PRIMARY KEY (session_id, seat)
)''',
];

/// v2 tables (PRD 6.4): live round log, archived games.
const List<String> historySchema = [
  '''
CREATE TABLE round_log (
  session_id TEXT    NOT NULL REFERENCES session(id) ON DELETE CASCADE,
  round      INTEGER NOT NULL CHECK (round >= 1),
  taker      INTEGER NOT NULL CHECK (taker BETWEEN 0 AND 59),
  giver      INTEGER NOT NULL CHECK (giver BETWEEN 0 AND 59),
  result     TEXT    NOT NULL CHECK (result IN ('truth','dare','pass')),
  CHECK (taker <> giver),
  PRIMARY KEY (session_id, round)
)''',
  '''
CREATE TABLE game (
  id           TEXT    PRIMARY KEY,
  started_at   INTEGER NOT NULL,
  ended_at     INTEGER NOT NULL CHECK (ended_at >= started_at),
  player_count INTEGER NOT NULL CHECK (player_count BETWEEN 2 AND 60),
  deleted_at   INTEGER
)''',
  '''
CREATE TABLE game_player (
  game_id TEXT    NOT NULL REFERENCES game(id) ON DELETE CASCADE,
  seat    INTEGER NOT NULL CHECK (seat BETWEEN 0 AND 59),
  name    TEXT    CHECK (name IS NULL OR length(name) BETWEEN 1 AND 40),
  PRIMARY KEY (game_id, seat)
)''',
  '''
CREATE TABLE game_round (
  game_id TEXT    NOT NULL REFERENCES game(id) ON DELETE CASCADE,
  round   INTEGER NOT NULL CHECK (round >= 1),
  taker   INTEGER NOT NULL CHECK (taker BETWEEN 0 AND 59),
  giver   INTEGER NOT NULL CHECK (giver BETWEEN 0 AND 59),
  result  TEXT    NOT NULL CHECK (result IN ('truth','dare','pass')),
  CHECK (taker <> giver),
  PRIMARY KEY (game_id, round)
)''',
];

Future<Database> openSessionDb({
  DatabaseFactory? factory,
  String path = 'spinfolk.db',
}) async {
  final f = factory ?? databaseFactory;
  // Resolve once: open and rename must agree (a relative name is not cwd).
  final full = path.startsWith('/') || path == inMemoryDatabasePath
      ? path
      : '${await f.getDatabasesPath()}/$path';
  Future<Database> open() => f.openDatabase(
    full,
    options: OpenDatabaseOptions(
      version: sessionDbVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        for (final sql in [...sessionSchema, ...historySchema]) {
          await db.execute(sql);
        }
      },
      onUpgrade: (db, from, _) async {
        if (from < 2) {
          for (final sql in historySchema) {
            await db.execute(sql);
          }
        }
      },
      // Soft-deleted games are purged at open (children cascade).
      // Best-effort: a failed purge must not fail the open.
      onOpen: (db) async {
        try {
          await db.delete('game', where: 'deleted_at IS NOT NULL');
        } on DatabaseException {
          // retried at next open
        }
      },
      // Never wipe on downgrade; main shows a static notice when open fails.
      onDowngrade: (db, from, to) =>
          throw StateError('database v$from is newer than v$to'),
    ),
  );
  try {
    return await open();
  } on DatabaseException catch (e) {
    // Only a corrupt file is reset; transient errors (CANTOPEN, FULL, BUSY)
    // rethrow so history survives. The unreadable file is kept as one backup.
    // SQLITE_CORRUPT 11, SQLITE_NOTADB 26 (mask off extended codes).
    final c = (e.getResultCode() ?? 0) & 0xff;
    if (c != 11 && c != 26) rethrow;
    for (final x in ['', '-journal', '-wal', '-shm']) {
      final file = File('$full$x');
      if (file.existsSync()) await file.rename('$full.corrupt$x');
    }
    return open();
  }
}
