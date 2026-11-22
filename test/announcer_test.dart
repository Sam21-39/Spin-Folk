import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spinfolk/features/session/domain/entities/session.dart';
import 'package:spinfolk/features/session/domain/rules/labels.dart';
import 'package:spinfolk/features/session/presentation/bloc/session_bloc.dart';
import 'package:spinfolk/features/settings/domain/prefs.dart';
import 'package:spinfolk/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:spinfolk/platform/announcer.dart';
import 'package:spinfolk/platform/native_bridge.dart';

import 'support/fake_native.dart';
import 'support/fake_prefs_repository.dart';
import 'support/fake_session_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeSessionRepository repo;
  late FakePrefsRepository prefs;
  late FakeNative native;
  late NativeBridge bridge;
  late SessionBloc bloc;
  late SettingsCubit settings;
  late Announcer announcer;

  Future<void> boot({Prefs p = const Prefs(), Session? stored}) async {
    repo = FakeSessionRepository()..stored = stored;
    prefs = FakePrefsRepository()..stored = p;
    native = FakeNative()..install();
    bridge = NativeBridge();
    bloc = SessionBloc(repo, Random(1));
    settings = SettingsCubit(prefs, bridge);
    announcer = Announcer(bloc, bridge, settings)..start();
  }

  tearDown(() async {
    await announcer.close();
    await settings.close();
    await bridge.dispose();
    await bloc.close();
    native.uninstall();
  });

  Future<void> send(SessionEvent e) async {
    bloc.add(e);
    await pumpEventQueue();
  }

  Future<void> startAndReveal() async {
    await send(const AppStarted());
    await send(const SessionStarted(4, [null, null, null, null]));
    await send(const SpinRequested());
    await send(const SpinAnimationFinished());
  }

  Session session() => (bloc.state as SessionActive).session;
  List<Object?> spoken() => native
      .named('speech.speak')
      .map((c) => (c.arguments as Map)['text'])
      .toList();

  test('live reveal speaks once with defaults', () async {
    await boot();
    await startAndReveal();
    final c = native.named('speech.speak').single.arguments as Map;
    expect(c['text'], speechLine(session()));
    expect(c['rate'], 0.5);
    expect(c['voiceId'], isNull);
  });

  test('stored voice and rate are used', () async {
    await boot(p: const Prefs(voiceId: 'v1', rate: 0.6));
    await startAndReveal();
    final c = native.named('speech.speak').single.arguments as Map;
    expect((c['voiceId'], c['rate']), ('v1', 0.6));
  });

  test('backgrounded reveal is silent', () async {
    await boot();
    await send(const AppStarted());
    await send(const SessionStarted(4, [null, null, null, null]));
    await send(const SpinRequested());
    await send(const AppBackgrounded());
    expect(native.named('speech.speak'), isEmpty);
  });

  test('resumed revealed session is silent', () async {
    await boot(
      stored: Session(
        id: 's',
        startedAtMs: 0,
        players: [for (var i = 0; i < 4; i++) Player(seat: i)],
        phase: Phase.revealed,
        outcome: const Outcome(taker: 0, giver: 2),
      ),
    );
    await send(const AppStarted());
    await send(const ResumeConfirmed());
    expect(native.named('speech.speak'), isEmpty);
  });

  test('announce off: no auto line, Replay still speaks', () async {
    await boot(p: const Prefs(announce: false));
    await startAndReveal();
    expect(native.named('speech.speak'), isEmpty);
    await send(const ReplayRequested());
    expect(native.named('speech.speak'), hasLength(1));
  });

  test('mode line only on Replay', () async {
    await boot();
    await startAndReveal();
    await send(const ModeChosen(Mode.truth));
    expect(native.named('speech.speak'), hasLength(1));
    await send(const ReplayRequested());
    expect(spoken().last, endsWith('chose Truth.'));
  });

  test('failed speak raises notice, next success clears it', () async {
    await boot();
    native.failSpeak = true;
    await startAndReveal();
    expect(announcer.state, isTrue);
    native.failSpeak = false;
    await send(const ReplayRequested());
    expect(announcer.state, isFalse);
  });

  test('speak failure resolving after Pass leaves notice off', () async {
    await boot();
    native
      ..failSpeak = true
      ..speakGate = Completer<void>();
    await startAndReveal();
    await send(const Passed());
    native.speakGate!.complete();
    await pumpEventQueue();
    expect(announcer.state, isFalse);
  });

  test('speech events', () async {
    await boot();
    await native.send('speech.event', {'state': 'error'});
    await pumpEventQueue();
    expect(announcer.state, isTrue);
    await native.send('speech.event', {'state': 'cancelled'});
    await native.send('speech.event', {'state': 'done'});
    await pumpEventQueue();
    expect(announcer.state, isTrue);
  });

  test('Passed and End stop speech and clear the notice', () async {
    await boot();
    native.failSpeak = true;
    await startAndReveal();
    expect(announcer.state, isTrue);
    await send(const Passed());
    expect(native.named('speech.stop'), hasLength(1));
    expect(announcer.state, isFalse);

    await send(const SpinRequested());
    await send(const SpinAnimationFinished());
    await send(const ModeChosen(Mode.dare)); // logs a round, so End archives
    await send(const EndConfirmed());
    expect(bloc.state, isNot(isA<SessionActive>()));
    expect(native.named('speech.stop'), hasLength(2));
    expect(announcer.state, isFalse);
  });

  test('preview speaks the sample even when announce is off', () async {
    await boot(p: const Prefs(announce: false));
    await announcer.preview();
    expect(spoken(), [Announcer.sampleLine]);
  });

  test('start twice: one call per reveal', () async {
    await boot();
    announcer.start();
    await startAndReveal();
    expect(native.named('speech.speak'), hasLength(1));
  });
}
