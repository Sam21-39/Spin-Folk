import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../features/session/domain/rules/labels.dart';
import '../features/session/presentation/bloc/session_bloc.dart';
import '../features/settings/presentation/cubit/settings_cubit.dart';
import 'native_bridge.dart';

/// State: true = show [unavailableText].
@lazySingleton
class Announcer extends Cubit<bool> {
  Announcer(this._bloc, this._bridge, this._settings) : super(false);

  static const String unavailableText =
      'Voice unavailable. Read the roles aloud.';
  static const String sampleLine = 'Player 3, give a challenge to Player 7.';

  final SessionBloc _bloc;
  final NativeBridge _bridge;
  final SettingsCubit _settings;

  late SessionState _prev;
  StreamSubscription<SessionState>? _sessionSub;
  StreamSubscription<SpeechEvent>? _speechSub;

  /// Subscribe; idempotent.
  void start() {
    if (_sessionSub != null) return;
    _prev = _bloc.state;
    _sessionSub = _bloc.stream.listen(_onState);
    _speechSub = _bridge.speechEvents.listen((e) {
      if (e == SpeechEvent.error) emit(true);
    });
  }

  /// Sheet "Play sample": ignores the Announcements switch.
  Future<void> preview() => _say(sampleLine);

  void _onState(SessionState next) {
    final prev = _prev;
    _prev = next;
    if (next is! SessionActive) {
      if (prev is SessionActive) _stop();
      return;
    }
    if (prev is! SessionActive || prev.session.id != next.session.id) return;
    if (prev.session.round != next.session.round) {
      _stop();
    } else if (next.liveReveal && _settings.state.prefs.announce ||
        next.replayCount > prev.replayCount) {
      _say(speechLine(next.session));
    }
  }

  void _stop() {
    unawaited(_bridge.stopSpeech());
    emit(false);
  }

  Future<void> _say(String? line) async {
    if (line == null) return;
    final p = _settings.state.prefs;
    final s = _bloc.state;
    final at = s is SessionActive ? (s.session.id, s.session.round) : null;
    final ok = await _bridge.speak(line, voiceId: p.voiceId, rate: p.rate);
    final n = _bloc.state;
    final now = n is SessionActive ? (n.session.id, n.session.round) : null;
    if (!isClosed && now == at) emit(!ok);
  }

  @override
  Future<void> close() async {
    await _sessionSub?.cancel();
    await _speechSub?.cancel();
    return super.close();
  }
}
