import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spinfolk/features/session/domain/entities/session.dart';
import 'package:spinfolk/features/session/presentation/bloc/session_bloc.dart';
import 'package:spinfolk/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:spinfolk/platform/live_activity_sync.dart';
import 'package:spinfolk/platform/native_bridge.dart';

import 'support/fake_native.dart';
import 'support/fake_prefs_repository.dart';
import 'support/fake_session_repository.dart';

const _id = '0123456789abcdef0123456789abcdef';

Session _s({
  int n = 8,
  int round = 1,
  Phase phase = Phase.ready,
  Outcome? o,
  Mode? m,
  List<RoundEntry> log = const [],
  List<String?>? names,
}) => Session(
  id: 'test',
  startedAtMs: 5,
  players: [for (var i = 0; i < n; i++) Player(seat: i, name: names?[i])],
  round: round,
  phase: phase,
  outcome: o,
  mode: m,
  log: log,
);

RoundEntry _e(int round, RoundResult r) =>
    RoundEntry(round: round, taker: 6, giver: 2, result: r);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('activityPayload', () {
    test('ready, first round: no roles', () {
      expect(activityPayload(_s()), {
        'sessionId': 'test',
        'startedAt': 5,
        'players': 8,
        'round': 1,
        'phase': 'ready',
      });
    });
    test('revealed', () {
      expect(
        activityPayload(
          _s(phase: Phase.revealed, o: const Outcome(taker: 6, giver: 2)),
        ),
        {
          'sessionId': 'test',
          'startedAt': 5,
          'players': 8,
          'round': 1,
          'phase': 'revealed',
          'taker': 6,
          'giver': 2,
          'takerLabel': 'Player 7',
          'giverLabel': 'Player 3',
        },
      );
    });
    test('challenge carries the mode', () {
      for (final m in Mode.values) {
        final p = activityPayload(
          _s(
            phase: Phase.challenge,
            o: const Outcome(taker: 6, giver: 2),
            m: m,
          ),
        );
        expect(p['mode'], m.name);
        expect(p['phase'], 'challenge');
      }
    });
    test('ready after truth/dare: last round roles and mode', () {
      final p = activityPayload(_s(round: 2, log: [_e(1, RoundResult.dare)]));
      expect(p['taker'], 6);
      expect(p['giver'], 2);
      expect(p['mode'], 'dare');
      expect(p['round'], 2);
    });
    test('ready after a pass: no roles', () {
      final p = activityPayload(_s(round: 2, log: [_e(1, RoundResult.pass)]));
      expect(p.containsKey('taker'), isFalse);
      expect(p.containsKey('mode'), isFalse);
    });
    test('ready, last seat gone: no roles', () {
      final p = activityPayload(
        _s(n: 4, round: 2, log: [_e(1, RoundResult.truth)]),
      );
      expect(p.containsKey('taker'), isFalse);
    });
    test('named players', () {
      final p = activityPayload(
        _s(
          names: ['Riya', ...List.filled(7, null)],
          phase: Phase.revealed,
          o: const Outcome(taker: 1, giver: 0),
        ),
      );
      expect(p['giverLabel'], 'Riya · P1');
      expect(p['takerLabel'], 'Player 2');
    });
  });

  group('LiveActivitySync', () {
    late FakeSessionRepository repo;
    late FakeNative native;
    late NativeBridge bridge;
    late SessionBloc bloc;
    late SettingsCubit settings;
    late LiveActivitySync sync;

    Future<void> boot({Session? stored}) async {
      repo = FakeSessionRepository()..stored = stored;
      native = FakeNative()..install();
      bridge = NativeBridge();
      bloc = SessionBloc(repo, Random(1));
      settings = SettingsCubit(FakePrefsRepository(), bridge);
      sync = LiveActivitySync(bloc, bridge, settings);
      bloc.add(const AppStarted());
      await pumpEventQueue();
      sync.start();
      await pumpEventQueue();
    }

    tearDown(() async {
      await sync.dispose();
      await settings.close();
      await bridge.dispose();
      native.uninstall();
      await bloc.close();
    });

    Future<void> send(SessionEvent e) async {
      bloc.add(e);
      await pumpEventQueue();
    }

    List<String> names() => [for (final c in native.calls) c.method];
    List<MethodCall> acts() => [
      for (final c in native.calls)
        if (c.method.startsWith('activity.')) c,
    ];
    Future<void> startGame() async {
      await send(SessionStarted(8, List.filled(8, null)));
      native.calls.clear();
    }

    test('launch without session: ready + reconcile null, no sync', () async {
      await boot();
      expect(names(), ['url.ready', 'activity.reconcile']);
      expect(native.calls[1].arguments, {'sessionId': null});
    });

    test('session start syncs once, phase ready', () async {
      await boot();
      native.calls.clear();
      await send(SessionStarted(8, List.filled(8, null)));
      expect(names(), ['activity.sync']);
      expect(native.calls.single.arguments, containsPair('phase', 'ready'));
    });

    test('loop: nothing while spinning, sync at reveal, mode, next', () async {
      await boot();
      await startGame();
      await send(const SpinRequested());
      expect(acts(), isEmpty);
      await send(const SpinAnimationFinished());
      expect(acts().length, 1);
      expect(acts().single.arguments, containsPair('phase', 'revealed'));
      expect((acts().single.arguments as Map)['giverLabel'], isNotNull);
      native.calls.clear();
      await send(const ReplayRequested());
      expect(acts(), isEmpty);
      await send(const ModeChosen(Mode.truth));
      expect(acts().single.arguments, containsPair('mode', 'truth'));
      native.calls.clear();
      await send(const NextRoundRequested());
      final a = acts().single.arguments as Map;
      expect(a['round'], 2);
      expect(a['phase'], 'ready');
      expect(a['mode'], 'truth');
    });

    test('backgrounded reveal syncs', () async {
      await boot();
      await startGame();
      await send(const SpinRequested());
      await send(const AppBackgrounded());
      expect(acts().length, 1);
      expect(acts().single.arguments, containsPair('phase', 'revealed'));
    });

    test('failed write: no call', () async {
      await boot();
      await startGame();
      await send(const SpinRequested());
      await send(const SpinAnimationFinished());
      native.calls.clear();
      repo.failWrites = true;
      await send(const ModeChosen(Mode.dare));
      expect(acts(), isEmpty);
    });

    test('players edited syncs', () async {
      await boot();
      await startGame();
      await send(PlayersEdited(5, List.filled(5, null)));
      expect(acts().single.arguments, containsPair('players', 5));
    });

    test('end sends activity.end, then nothing', () async {
      await boot();
      await startGame();
      await send(const EndConfirmed());
      expect(names(), ['activity.end']);
      expect(native.calls.single.arguments, {'sessionId': 'test', 'rounds': 0});
    });

    test('end reports played rounds (log length), not the round', () async {
      await boot(
        stored: _s(
          round: 4,
          log: [
            _e(1, RoundResult.truth),
            _e(2, RoundResult.dare),
            _e(3, RoundResult.pass),
          ],
        ),
      );
      await send(const ResumeConfirmed());
      native.calls.clear();
      await send(const EndConfirmed());
      expect(names(), ['activity.end']);
      expect(native.calls.single.arguments, {'sessionId': 'test', 'rounds': 3});
    });

    test(
      'foreground: reconcile + forced sync; spinning: reconcile only',
      () async {
        await boot();
        await startGame();
        sync.foreground();
        await pumpEventQueue();
        expect(names(), ['activity.reconcile', 'activity.sync']);
        expect(native.calls.first.arguments, {'sessionId': 'test'});
        native.calls.clear();
        await send(const SpinRequested());
        sync.foreground();
        await pumpEventQueue();
        expect(names(), ['activity.reconcile']);
      },
    );

    test('stored session at launch: reconcile keeps it, then sync', () async {
      await boot(stored: _s());
      expect(names(), ['url.ready', 'activity.reconcile', 'activity.sync']);
      expect(native.calls[1].arguments, {'sessionId': 'test'});
      expect(native.calls[2].arguments, containsPair('sessionId', 'test'));
      native.calls.clear();
      await send(const ResumeConfirmed());
      expect(names(), isEmpty); // same payload: deduped
    });

    test('resume prompt, then new game: end old, sync new, in order', () async {
      await boot(stored: _s());
      native.calls.clear();
      await send(SessionStarted(8, List.filled(8, null)));
      expect(names(), ['activity.end', 'activity.sync']);
      expect(native.calls[0].arguments, containsPair('sessionId', 'test'));
      final next = (native.calls[1].arguments as Map)['sessionId'];
      expect(next, isNot('test'));
    });

    test('status reaches settings; errors never escape', () async {
      await boot();
      native.activityState = 'disabled';
      await startGame();
      expect(settings.state.activityStatus, ActivityStatus.disabled);
      expect(settings.state.lockScreenOff, isTrue);
      native.activityState = 'bogus';
      await send(PlayersEdited(5, List.filled(5, null)));
      expect(settings.state.activityStatus, ActivityStatus.error);
      expect(settings.state.lockScreenOff, isFalse);
    });

    test('link resumes the stored session; bad links ignored', () async {
      await boot(
        stored: Session(id: _id, startedAtMs: 0, players: _s().players),
      );
      await native.send('url.open', {'sessionId': 'f' * 32});
      await pumpEventQueue();
      expect(bloc.state, isA<ResumePrompt>());
      await native.send('url.open', {'sessionId': _id.toUpperCase()});
      await native.send('url.open', 'nope');
      await pumpEventQueue();
      expect(bloc.state, isA<ResumePrompt>());
      await native.send('url.open', {'sessionId': _id});
      await pumpEventQueue();
      expect(bloc.state, isA<SessionActive>());
    });

    test('calls keep enqueue order with a slow fake', () async {
      await boot();
      native.activityDelay = const Duration(milliseconds: 20);
      await send(SessionStarted(8, List.filled(8, null)));
      await send(PlayersEdited(5, List.filled(5, null)));
      await send(const EndConfirmed());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(names().skip(2), [
        'activity.sync',
        'activity.sync',
        'activity.end',
      ]);
    });
  });
}
