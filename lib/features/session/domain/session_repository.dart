import 'entities/game_record.dart';
import 'entities/session.dart';

abstract interface class SessionRepository {
  /// null when nothing is stored. Throws CorruptSession (after deleting the
  /// rows) or StorageFailure. Includes the round log.
  Future<Session?> load();

  /// One transaction: archives a stored session that has at least one logged
  /// round, deletes it, inserts the new one. Creates id and start time.
  /// Returns round 1, phase ready.
  Future<Session> start(List<Player> players);

  /// Single UPDATE of round, phase, taker, giver, mode. With [log], the same
  /// transaction also upserts that round_log row.
  Future<void> saveRound(Session session, {RoundEntry? log});

  /// Transaction: player_count + all player rows. Keeps the id.
  Future<void> replacePlayers(String id, List<Player> players);

  /// Archives to History and deletes the session. Null when nothing was
  /// archived (no logged round).
  Future<GameRecord?> end(Session session);
}
