import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/failure.dart';
import '../../domain/entities/session.dart';
import '../../domain/rules/labels.dart';
import '../../domain/rules/selection.dart';
import '../../domain/session_repository.dart';

part 'session_event.dart';
part 'session_state.dart';

@lazySingleton
class SessionBloc extends Bloc<SessionEvent, SessionState> {
  SessionBloc(this._repo, this._rng) : super(const SessionLoading()) {
    // One handler, strictly sequential: every event sees the state left by the
    // previous one, so no re-checks after awaits (stdlib stand-in for
    // bloc_concurrency.sequential).
    on<SessionEvent>(
      _onEvent,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
  }

  final SessionRepository _repo;
  final Random _rng;

  Future<void> _onEvent(SessionEvent event, Emitter<SessionState> emit) {
    final s = state;
    return switch (event) {
      AppStarted() => _appStarted(emit),
      ResumeConfirmed() => _resume(s, emit),
      SessionLinkOpened(:final id) =>
        s is ResumePrompt && s.session.id == id ? _resume(s, emit) : _noop(),
      SessionStarted(:final count, :final names) => _start(count, names, emit),
      SpinRequested() => _spin(emit),
      SpinAnimationFinished() || AppBackgrounded() => _finishSpin(emit),
      ModeChosen(:final mode) => _persist(
        emit,
        (a) => a.session.phase == Phase.revealed,
        (a) => a.session.chose(mode),
      ),
      Passed() => _persist(
        emit,
        (a) =>
            a.session.phase == Phase.revealed ||
            a.session.phase == Phase.challenge,
        (a) => a.session.nextRound(),
      ),
      NextRoundRequested() => _persist(
        emit,
        (a) => a.session.phase == Phase.challenge,
        (a) => a.session.nextRound(),
      ),
      PlayersEdited(:final count, :final names) => _editPlayers(
        count,
        names,
        emit,
      ),
      EndConfirmed() => _end(emit),
      ReplayRequested() => _replay(emit),
    };
  }

  Future<void> _noop() async {}

  List<Player>? _players(int count, List<String?> names) {
    if (count < 2 || count > 60 || names.length != count) return null;
    return [
      for (var i = 0; i < count; i++)
        Player(seat: i, name: normalizeName(names[i])),
    ];
  }

  Future<void> _appStarted(Emitter<SessionState> emit) async {
    if (state is! SessionLoading) return;
    try {
      final s = await _repo.load();
      emit(s == null ? const NoSession() : ResumePrompt(s));
    } on Object {
      // Storage, corrupt and unexpected errors look the same to the player.
      emit(NoSession(notice: const CorruptSession().message));
    }
  }

  Future<void> _resume(SessionState s, Emitter<SessionState> emit) async {
    if (s is! ResumePrompt) return;
    final o = s.session.outcome;
    emit(
      SessionActive(
        session: s.session,
        orientation: o == null ? 0 : seatAngle(o.taker, s.session.playerCount),
      ),
    );
  }

  Future<void> _start(
    int count,
    List<String?> names,
    Emitter<SessionState> emit,
  ) async {
    final players = _players(count, names);
    if (state is! NoSession || players == null) return;
    try {
      emit(SessionActive(session: await _repo.start(players)));
    } on Failure catch (f) {
      emit(NoSession(notice: f.message));
    }
  }

  Future<void> _spin(Emitter<SessionState> emit) async {
    final a = state;
    if (a is! SessionActive || a.spinning || a.session.phase != Phase.ready) {
      return;
    }
    final n = a.session.playerCount;
    final o = pickRoles(n, _rng);
    final plan = spinPlan(
      current: a.orientation,
      taker: o.taker,
      n: n,
      rng: _rng,
    );
    final next = a.session.revealed(o);
    // Emitted before the first await: a second SpinRequested sees spinning.
    emit(
      SessionActive(
        session: next,
        spinning: true,
        spinPlan: plan,
        orientation: a.orientation,
        replayCount: a.replayCount,
      ),
    );
    try {
      await _repo.saveRound(next);
    } on Failure catch (f) {
      emit(
        SessionActive(
          session: a.session,
          orientation: a.orientation,
          failure: f,
          replayCount: a.replayCount,
        ),
      );
    }
  }

  Future<void> _finishSpin(Emitter<SessionState> emit) async {
    final a = state;
    final plan = a is SessionActive ? a.spinPlan : null;
    if (a is! SessionActive || !a.spinning || plan == null) return;
    emit(
      SessionActive(
        session: a.session,
        orientation: seatAngle(a.session.outcome!.taker, a.session.playerCount),
        replayCount: a.replayCount,
      ),
    );
  }

  /// ModeChosen / Passed / NextRoundRequested: persist the next session, then emit.
  Future<void> _persist(
    Emitter<SessionState> emit,
    bool Function(SessionActive) applies,
    Session Function(SessionActive) transition,
  ) async {
    final a = state;
    if (a is! SessionActive || a.spinning || !applies(a)) return;
    final next = transition(a);
    try {
      await _repo.saveRound(next);
      emit(_with(a, next));
    } on Failure catch (f) {
      emit(_with(a, a.session, failure: f));
    }
  }

  SessionActive _with(SessionActive a, Session s, {Failure? failure}) =>
      SessionActive(
        session: s,
        orientation: a.orientation,
        failure: failure,
        replayCount: a.replayCount,
      );

  Future<void> _editPlayers(
    int count,
    List<String?> names,
    Emitter<SessionState> emit,
  ) async {
    final a = state;
    final players = _players(count, names);
    if (a is! SessionActive ||
        a.spinning ||
        a.session.phase != Phase.ready ||
        players == null) {
      return;
    }
    try {
      await _repo.replacePlayers(a.session.id, players);
      emit(
        SessionActive(
          session: a.session.withPlayers(players),
          replayCount: a.replayCount,
        ),
      );
    } on Failure catch (f) {
      emit(_with(a, a.session, failure: f));
    }
  }

  Future<void> _end(Emitter<SessionState> emit) async {
    final s = state;
    if (s is! ResumePrompt && !(s is SessionActive && !s.spinning)) return;
    try {
      await _repo.end();
      emit(const NoSession());
    } on Failure catch (f) {
      emit(switch (s) {
        ResumePrompt() => ResumePrompt(s.session, failure: f),
        SessionActive() => _with(s, s.session, failure: f),
        _ => s,
      });
    }
  }

  Future<void> _replay(Emitter<SessionState> emit) async {
    final a = state;
    if (a is! SessionActive || a.spinning || a.session.phase == Phase.ready) {
      return;
    }
    emit(
      SessionActive(
        session: a.session,
        orientation: a.orientation,
        replayCount: a.replayCount + 1,
      ),
    );
  }
}
