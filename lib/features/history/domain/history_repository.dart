import '../../session/domain/entities/game_record.dart';

abstract interface class HistoryRepository {
  /// Not deleted, newest first.
  Future<List<GameRecord>> games();

  Future<void> softDelete(List<String> ids, int atMs);

  Future<void> restore(List<String> ids);

  /// Removes every soft-deleted game (children cascade).
  Future<void> purgeDeleted();
}
