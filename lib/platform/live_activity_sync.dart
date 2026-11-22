import 'dart:async';
import 'dart:convert';

import 'package:injectable/injectable.dart';

import '../features/session/domain/entities/session.dart';
import '../features/session/domain/rules/labels.dart';
import '../features/session/presentation/bloc/session_bloc.dart';
import '../features/settings/presentation/cubit/settings_cubit.dart';
import 'native_bridge.dart';

/// Pure. The `activity.sync` arguments for a session that is not spinning.
/// In phase ready the roles are the last logged round's (Truth or Dare only).
Map<String, Object?> activityPayload(Session s) {
  final o = s.outcome;
  final last = s.log.isEmpty ? null : s.log.last;
  final int? taker, giver;
  final Mode? mode;
  if (s.phase == Phase.ready) {
    final ok =
        last != null &&
        last.result != RoundResult.pass &&
        last.taker < s.playerCount &&
        last.giver < s.playerCount;
    taker = ok ? last.taker : null;
    giver = ok ? last.giver : null;
    mode = ok
        ? (last.result == RoundResult.dare ? Mode.dare : Mode.truth)
        : null;
  } else {
    taker = o?.taker;
    giver = o?.giver;
    mode = s.phase == Phase.challenge ? s.mode : null;
  }
  return {
    'sessionId': s.id,
    'startedAt': s.startedAtMs,
    'players': s.playerCount,
    'round': s.round,
    'phase': s.phase.name,
    if (taker != null && giver != null) ...{
      'taker': taker,
      'giver': giver,
      'takerLabel': displayLabel(playerAt(s.players, taker)),
      'giverLabel': displayLabel(playerAt(s.players, giver)),
      'mode': ?mode?.name,
    },
  };
}

/// Mirrors the session onto the Live Activity. Never awaited by gameplay.
@lazySingleton
class LiveActivitySync {
  LiveActivitySync(this._bloc, this._bridge, this._settings);

  final SessionBloc _bloc;
  final NativeBridge _bridge;
  final SettingsCubit _settings;

  Session? _known;
  String? _sent;
  Future<void> _tail = Future.value(); // serial: calls never overtake
  StreamSubscription<SessionState>? _stateSub;
  StreamSubscription<String>? _linkSub;

  static Session? _sessionOf(SessionState s) => switch (s) {
    SessionActive(:final session) => session,
    ResumePrompt(:final session) => session,
    _ => null,
  };

  /// Idempotent. Subscribe to links first so a held cold-start link is kept.
  void start() {
    if (_stateSub != null) return;
    _linkSub = _bridge.sessionLinks.listen(
      (id) => _bloc.add(SessionLinkOpened(id)),
    );
    unawaited(_bridge.linksReady());
    foreground();
    _stateSub = _bloc.stream.listen(_onState);
  }

  /// Launch and every return to foreground.
  void foreground() {
    final id = _sessionOf(_bloc.state)?.id;
    _enqueue(() => _bridge.reconcileActivities(id));
    _sent = null;
    _onState(_bloc.state);
  }

  void _onState(SessionState state) {
    if (state is SessionActive && state.spinning) return; // never spoil
    if (state is SessionLoading) return;
    final session = _sessionOf(state);
    final known = _known;
    if (known != null && known.id != session?.id) {
      _enqueue(() => _bridge.endActivity(known.id, known.log.length));
      _sent = null;
      _known = null;
    }
    if (session == null) return;
    _known = session;
    final payload = activityPayload(session);
    final encoded = jsonEncode(payload);
    if (encoded == _sent) return;
    _sent = encoded;
    _enqueue(() async {
      _settings.activityStatusChanged(await _bridge.syncActivity(payload));
    });
  }

  void _enqueue(Future<void> Function() op) {
    _tail = _tail.then((_) => op()).catchError((Object _) {});
  }

  @disposeMethod
  Future<void> dispose() async {
    await _stateSub?.cancel();
    await _linkSub?.cancel();
  }
}
