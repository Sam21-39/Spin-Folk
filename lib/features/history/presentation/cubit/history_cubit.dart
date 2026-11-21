import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/failure.dart';
import '../../../session/domain/entities/game_record.dart';
import '../../domain/history_repository.dart';

final class HistoryState {
  const HistoryState({
    this.loaded = false,
    this.games = const [],
    this.pending = const [],
    this.failure,
  });
  final bool loaded;

  /// Visible, newest first.
  final List<GameRecord> games;

  /// Soft-deleted, still undoable.
  final List<GameRecord> pending;
  final Failure? failure;

  @override
  bool operator ==(Object other) =>
      other is HistoryState &&
      other.loaded == loaded &&
      other.failure == failure &&
      listEquals(other.games, games) &&
      listEquals(other.pending, pending);

  @override
  int get hashCode => Object.hash(
    loaded,
    failure,
    Object.hashAll(games),
    Object.hashAll(pending),
  );
}

@lazySingleton
class HistoryCubit extends Cubit<HistoryState> {
  HistoryCubit(this._repo) : super(const HistoryState());

  static const undoWindow = Duration(seconds: 5);

  final HistoryRepository _repo;
  Timer? _timer;

  HistoryState _next({
    List<GameRecord>? games,
    List<GameRecord>? pending,
    Failure? failure,
  }) => HistoryState(
    loaded: true,
    games: games ?? state.games,
    pending: pending ?? state.pending,
    failure: failure,
  );

  // One chain: repo work never interleaves; state emits stay synchronous.
  Future<void>? _chain;

  Future<void> _serial(Future<void> Function() f) {
    Future<void> run() async {
      if (isClosed) return;
      try {
        await f();
      } catch (_) {
        // Unexpected error: swallow so unawaited callers raise no zone error.
        if (!isClosed) emit(_next(failure: const StorageFailure()));
      }
    }

    final r = _chain?.then((_) => run()) ?? run();
    _chain = r.catchError((_) {});
    return r;
  }

  void _arm() {
    if (isClosed) return;
    _timer?.cancel();
    _timer = Timer(undoWindow, purgeNow);
  }

  Future<void> load() => _serial(() async {
    try {
      emit(_next(games: await _repo.games()));
    } on Failure catch (f) {
      emit(_next(failure: f));
    }
  });

  Future<void> delete(List<String> ids) {
    final removed = [
      for (final g in state.games)
        if (ids.contains(g.id)) g,
    ];
    if (removed.isEmpty) return Future.value();
    final hadPending = state.pending.isNotEmpty;
    // Synchronous: a Dismissible must leave the tree next frame.
    emit(
      _next(
        games: [
          for (final g in state.games)
            if (!ids.contains(g.id)) g,
        ],
        pending: removed,
      ),
    );
    _timer?.cancel();
    return _serial(() async {
      try {
        if (hadPending) await _repo.purgeDeleted();
        await _repo.softDelete(
          ids,
          DateTime.now().toUtc().millisecondsSinceEpoch,
        );
        _arm();
      } on Failure catch (f) {
        List<GameRecord>? games;
        try {
          games = await _repo.games();
        } on Failure {
          games = null;
        }
        emit(_next(games: games, pending: const [], failure: f));
      }
    });
  }

  Future<void> undo() {
    if (state.pending.isEmpty) return Future.value();
    _timer?.cancel();
    final ids = [for (final g in state.pending) g.id];
    return _serial(() async {
      _timer?.cancel();
      try {
        await _repo.restore(ids);
        emit(_next(games: await _repo.games(), pending: const []));
      } on Failure catch (f) {
        emit(_next(failure: f));
        _arm();
      }
    });
  }

  /// Also the Phase 3 background hook.
  Future<void> purgeNow() {
    _timer?.cancel();
    if (state.pending.isEmpty) return Future.value();
    // Cleared first: an undo tapped during the purge is a no-op, not a lie.
    emit(_next(pending: const []));
    return _serial(() async {
      try {
        await _repo.purgeDeleted();
      } on Failure {
        // purged at next open
      }
    });
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
