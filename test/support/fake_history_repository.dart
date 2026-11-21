import 'package:spinfolk/core/failure.dart';
import 'package:spinfolk/features/history/domain/history_repository.dart';
import 'package:spinfolk/features/session/domain/entities/game_record.dart';

class FakeHistoryRepository implements HistoryRepository {
  FakeHistoryRepository([List<GameRecord> seed = const []]) : rows = [...seed];

  /// In-memory table (including soft-deleted rows), newest first.
  final List<GameRecord> rows;
  final Set<String> deleted = {};
  bool failWrites = false;
  bool failReads = false;
  final List<String> calls = [];

  void add(GameRecord g) => rows.insert(0, g);

  void _write(String name) {
    calls.add(name);
    if (failWrites) throw const StorageFailure();
  }

  @override
  Future<List<GameRecord>> games() async {
    calls.add('games');
    if (failReads) throw const StorageFailure();
    return [
      for (final g in rows)
        if (!deleted.contains(g.id)) g,
    ];
  }

  @override
  Future<void> softDelete(List<String> ids, int atMs) async {
    _write('softDelete');
    deleted.addAll(ids);
  }

  @override
  Future<void> restore(List<String> ids) async {
    _write('restore');
    deleted.removeAll(ids);
  }

  @override
  Future<void> purgeDeleted() async {
    _write('purgeDeleted');
    rows.removeWhere((g) => deleted.contains(g.id));
    deleted.clear();
  }
}
