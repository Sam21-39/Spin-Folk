import 'entities/session.dart';

abstract interface class SessionRepository {
  /// null when nothing is stored. Throws CorruptSession (after deleting the
  /// rows) or StorageFailure.
  Future<Session?> load();

  /// Replaces any stored session. Creates id and start time. Returns round 1,
  /// phase ready.
  Future<Session> start(List<Player> players);

  /// Single UPDATE of round, phase, taker, giver, mode.
  Future<void> saveRound(Session session);

  /// Transaction: player_count + all player rows. Keeps the id.
  Future<void> replacePlayers(String id, List<Player> players);

  /// DELETE FROM session (players cascade).
  Future<void> end();
}
