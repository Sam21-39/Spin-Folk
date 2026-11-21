import 'package:flutter_test/flutter_test.dart';
import 'package:spinfolk/core/failure.dart';
import 'package:spinfolk/features/history/presentation/cubit/history_cubit.dart';
import 'package:spinfolk/features/session/domain/entities/game_record.dart';
import 'package:spinfolk/features/session/domain/entities/session.dart';

import 'support/fake_history_repository.dart';

GameRecord game(String id) => GameRecord(
  id: id,
  startedAtMs: 0,
  endedAtMs: 1,
  players: [for (var i = 0; i < 4; i++) Player(seat: i)],
  rounds: const [
    RoundEntry(round: 1, taker: 0, giver: 2, result: RoundResult.truth),
  ],
);

void main() {
  late FakeHistoryRepository repo;
  late HistoryCubit cubit;

  setUp(() {
    repo = FakeHistoryRepository([game('a'), game('b'), game('c')]);
    cubit = HistoryCubit(repo);
  });
  tearDown(() => cubit.close());

  List<String> ids(List<GameRecord> l) => [for (final g in l) g.id];

  test('load', () async {
    expect(cubit.state.loaded, isFalse);
    await cubit.load();
    expect(cubit.state.loaded, isTrue);
    expect(ids(cubit.state.games), ['a', 'b', 'c']);
  });

  test('load failure keeps lists and sets failure', () async {
    await cubit.load();
    repo.failReads = true;
    await cubit.load();
    expect(ids(cubit.state.games), ['a', 'b', 'c']);
    expect(cubit.state.failure, isA<StorageFailure>());
  });

  test('delete emits the shortened list before its first await', () async {
    await cubit.load();
    final f = cubit.delete(['b']); // not awaited
    expect(ids(cubit.state.games), ['a', 'c']);
    expect(ids(cubit.state.pending), ['b']);
    await f;
    expect(repo.deleted, {'b'});
  });

  test('delete of an unknown id does nothing', () async {
    await cubit.load();
    final before = cubit.state;
    await cubit.delete(['zzz']);
    expect(cubit.state, before);
    expect(repo.calls.where((c) => c == 'softDelete'), isEmpty);
  });

  test('undo restores', () async {
    await cubit.load();
    await cubit.delete(['b', 'c']);
    await cubit.undo();
    expect(ids(cubit.state.games), ['a', 'b', 'c']);
    expect(cubit.state.pending, isEmpty);
    expect(repo.deleted, isEmpty);
  });

  test('undo with nothing pending is a no-op', () async {
    await cubit.load();
    await cubit.undo();
    expect(repo.calls.where((c) => c == 'restore'), isEmpty);
  });

  // testWidgets runs in FakeAsync: pump(duration) advances the 5 s timer.
  testWidgets('after 5 s the rows are purged and pending is empty', (
    tester,
  ) async {
    await cubit.load();
    await cubit.delete(['a']);
    expect(cubit.state.pending, hasLength(1));
    await tester.pump(const Duration(seconds: 4));
    expect(cubit.state.pending, hasLength(1));
    await tester.pump(const Duration(seconds: 2));
    expect(cubit.state.pending, isEmpty);
    expect(ids(repo.rows), ['b', 'c']);
    expect(repo.deleted, isEmpty);
  });

  testWidgets('two unawaited deletes: second stays pending, no leaked timer', (
    tester,
  ) async {
    await cubit.load();
    cubit.delete(['a']);
    await tester.pump(const Duration(seconds: 3));
    cubit.delete(['b']);
    await tester.pump(const Duration(milliseconds: 4900));
    expect(ids(cubit.state.pending), ['b']);
    await tester.pump(const Duration(milliseconds: 200));
    expect(cubit.state.pending, isEmpty);
  });

  test('undo during purge does not claim success', () async {
    await cubit.load();
    await cubit.delete(['a']);
    final p = cubit.purgeNow(); // not awaited
    expect(cubit.state.pending, isEmpty);
    await cubit.undo();
    await p;
    expect(repo.calls.where((c) => c == 'restore'), isEmpty);
    expect(ids(repo.rows), ['b', 'c']);
    expect(ids(cubit.state.games), ['b', 'c']);
  });

  test('a second delete purges the first', () async {
    await cubit.load();
    await cubit.delete(['a']);
    await cubit.delete(['b']);
    expect(ids(repo.rows), ['b', 'c']);
    expect(ids(cubit.state.pending), ['b']);
    expect(ids(cubit.state.games), ['c']);
  });

  test('failed soft delete restores the list and sets failure', () async {
    await cubit.load();
    repo.failWrites = true;
    await cubit.delete(['b']);
    expect(ids(cubit.state.games), ['a', 'b', 'c']);
    expect(cubit.state.pending, isEmpty);
    expect(cubit.state.failure, isA<StorageFailure>());
  });

  test('failed undo keeps pending and failure', () async {
    await cubit.load();
    await cubit.delete(['b']);
    repo.failWrites = true;
    await cubit.undo();
    expect(ids(cubit.state.pending), ['b']);
    expect(cubit.state.failure, isA<StorageFailure>());
  });

  test('purgeNow clears pending (also the background hook)', () async {
    await cubit.load();
    await cubit.delete(['a']);
    await cubit.purgeNow();
    expect(cubit.state.pending, isEmpty);
    expect(ids(repo.rows), ['b', 'c']);
  });

  test('purgeNow failure still clears pending', () async {
    await cubit.load();
    await cubit.delete(['a']);
    repo.failWrites = true;
    await cubit.purgeNow();
    expect(cubit.state.pending, isEmpty);
  });
}
