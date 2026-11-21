import 'package:sqflite/sqflite.dart';

const int sessionDbVersion = 1;

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

// No onUpgrade yet: there is no version 2. Add it with the first migration.
Future<Database> openSessionDb({
  DatabaseFactory? factory,
  String path = 'spinfolk.db',
}) async {
  final f = factory ?? databaseFactory;
  Future<Database> open() => f.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: sessionDbVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        for (final sql in sessionSchema) {
          await db.execute(sql);
        }
      },
      onDowngrade: onDatabaseDowngradeDelete,
    ),
  );
  try {
    return await open();
  } on DatabaseException {
    // Unreadable file must not brick the app; the session is disposable state.
    await f.deleteDatabase(path);
    return open();
  }
}
