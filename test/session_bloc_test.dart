import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spinfolk/core/failure.dart';
import 'package:spinfolk/features/session/domain/entities/game_record.dart';
import 'package:spinfolk/features/session/domain/entities/session.dart';
import 'package:spinfolk/features/session/domain/rules/selection.dart';
import 'package:spinfolk/features/session/presentation/bloc/session_bloc.dart';

import 'support/fake_history_repository.dart';
import 'support/fake_session_repository.dart';

List<String?> nulls(int n) => List.filled(n, null);

Session stored(int n, {Phase phase = Phase.ready, Outcome? o, Mode? m}) =>
    Session(
      id: 'test',
      startedAtMs: 0,
      players: [for (var i = 0; i < n; i++) Player(seat: i)],
      phase: phase,
      outcome: o,
      mode: m,
    );

void main() {
  late FakeSessionRepository repo;
  late SessionBloc bloc;

  late FakeHistoryRepository history;

  setUp(() {
    history = FakeHistoryRepository();
    repo = FakeSessionRepository(history);
    bloc = SessionBloc(repo, Random(1));
  });
  tearDown(() => bloc.close());

  Future<void> send(SessionEvent e) async {
    bloc.add(e);
    await pumpEventQueue();
  }

  Future<SessionActive> startGame(int n) async {
    await send(const AppStarted());
    await send(SessionStarted(n, nulls(n)));
    return bloc.state as SessionActive;
  }

  SessionActive active() => bloc.state as SessionActive;

  Future<void> spinAndFinish() async {
    await send(const SpinRequested());
    await send(const SpinAnimationFinished());
  }

  group('AppStarted', () {
    test('empty', () async {
      await send(const AppStarted());
      expect(bloc.state, const NoSession());
    });
    test('stored session', () async {
      repo.stored = stored(4);
      await send(const AppStarted());
      expect(bloc.state, ResumePrompt(stored(4)));
    });
    test('corrupt', () async {
      repo.loadError = const CorruptSession();
      await send(const AppStarted());
      expect(
        bloc.state,
        const NoSession(notice: "Couldn't restore the last game"),
      );
    });
    test('second ignored', () async {
      await send(const AppStarted());
      repo.stored = stored(4);
      await send(const AppStarted());
      expect(bloc.state, const NoSession());
      expect(repo.calls, ['load']);
    });
  });

  group('ResumeConfirmed', () {
    test('ready -> orientation 0', () async {
      repo.stored = stored(8);
      await send(const AppStarted());
      await send(const ResumeConfirmed());
      expect(active().orientation, 0);
    });
    test('revealed -> orientation at taker', () async {
      repo.stored = stored(
        8,
        phase: Phase.revealed,
        o: const Outcome(taker: 2, giver: 6),
      );
      await send(const AppStarted());
      await send(const ResumeConfirmed());
      expect(active().orientation, seatAngle(2, 8));
      expect(active().spinning, isFalse);
    });
  });

  group('SessionStarted', () {
    test('starts', () async {
      final a = await startGame(8);
      expect(a.session.round, 1);
      expect(a.session.phase, Phase.ready);
      expect(repo.calls, ['load', 'start']);
    });
    test('invalid input ignored', () async {
      await send(const AppStarted());
      await send(SessionStarted(1, nulls(1)));
      await send(SessionStarted(61, nulls(61)));
      await send(SessionStarted(5, nulls(4)));
      expect(bloc.state, const NoSession());
      expect(repo.calls, ['load']);
    });
    test('names normalised', () async {
      await send(const AppStarted());
      await send(const SessionStarted(3, [' Riya ', '', null]));
      expect(active().session.players.map((p) => p.name), ['Riya', null, null]);
    });
    test('write failure', () async {
      await send(const AppStarted());
      repo.failWrites = true;
      await send(SessionStarted(3, nulls(3)));
      expect(bloc.state, const NoSession(notice: "Couldn't save. Try again."));
    });
  });

  test('AppStarted survives a non-Failure load error', () async {
    repo.loadError = StateError('boom');
    await send(const AppStarted());
    expect(bloc.state, NoSession(notice: const CorruptSession().message));
  });

  group('spin', () {
    test('first emission, persisted, finish', () async {
      await startGame(8);
      final emitted = <SessionState>[];
      final sub = bloc.stream.listen(emitted.add);
      await send(const SpinRequested());
      final first = emitted.first as SessionActive;
      expect(first.spinning, isTrue);
      expect(first.spinPlan, isNotNull);
      expect(first.session.phase, Phase.revealed);
      expect(repo.stored!.phase, Phase.revealed);
      await send(const SpinAnimationFinished());
      await sub.cancel();
      final taker = active().session.outcome!.taker;
      expect(active().spinning, isFalse);
      expect(active().spinPlan, isNull);
      expect(active().orientation, closeTo(seatAngle(taker, 8), 1e-9));
    });

    test('double spin: one outcome, one write', () async {
      await startGame(8);
      final emitted = <SessionState>[];
      final sub = bloc.stream.listen(emitted.add);
      final gate = repo.saveGate = Completer<void>();
      bloc.add(const SpinRequested());
      await pumpEventQueue();
      // Save in flight: spinning already, repo still ready.
      expect(active().spinning, isTrue);
      expect(repo.stored!.phase, Phase.ready);
      expect(repo.calls.where((c) => c == 'saveRound'), hasLength(1));
      bloc.add(const SpinRequested());
      gate.complete();
      await pumpEventQueue();
      await sub.cancel();
      expect(repo.calls.where((c) => c == 'saveRound'), hasLength(1));
      expect(
        emitted.whereType<SessionActive>().where((s) => s.spinning),
        hasLength(1),
      );
      expect(active().session.outcome, pickRoles(8, Random(1)));
    });

    test('ignored while revealed or challenge', () async {
      await startGame(8);
      await spinAndFinish();
      final o = active().session.outcome;
      repo.calls.clear();
      await send(const SpinRequested());
      expect(active().session.outcome, o);
      await send(const ModeChosen(Mode.truth));
      repo.calls.clear();
      await send(const SpinRequested());
      expect(repo.calls, isEmpty);
      expect(active().session.phase, Phase.challenge);
    });

    test('write failure rolls back to ready; retry works', () async {
      await startGame(8);
      repo.failWrites = true;
      await send(const SpinRequested());
      expect(active().session.phase, Phase.ready);
      expect(active().spinning, isFalse);
      expect(active().failure, isA<StorageFailure>());
      expect(repo.stored!.phase, Phase.ready);
      repo.failWrites = false;
      await send(const SpinRequested());
      expect(active().spinning, isTrue);
      expect(active().failure, isNull);
    });

    test('AppBackgrounded finishes a spin, otherwise nothing', () async {
      await startGame(8);
      final emitted = <SessionState>[];
      final sub = bloc.stream.listen(emitted.add);
      await send(const AppBackgrounded());
      await send(const SpinAnimationFinished());
      expect(emitted, isEmpty);
      await send(const SpinRequested());
      emitted.clear();
      await send(const AppBackgrounded());
      await sub.cancel();
      expect(emitted, hasLength(1));
      expect(active().spinning, isFalse);
      expect(active().session.phase, Phase.revealed);
    });
  });

  group('choices', () {
    test('ModeChosen', () async {
      await startGame(8);
      await send(const ModeChosen(Mode.truth));
      expect(active().session.phase, Phase.ready);
      await spinAndFinish();
      await send(const ModeChosen(Mode.truth));
      expect(active().session.phase, Phase.challenge);
      expect(active().session.mode, Mode.truth);
    });

    test('ModeChosen failure keeps revealed', () async {
      await startGame(8);
      await spinAndFinish();
      repo.failWrites = true;
      await send(const ModeChosen(Mode.dare));
      expect(active().session.phase, Phase.revealed);
      expect(active().failure, isA<StorageFailure>());
    });

    test('Passed / NextRoundRequested', () async {
      await startGame(8);
      await send(const Passed());
      await send(const NextRoundRequested());
      expect(active().session.round, 1);
      await spinAndFinish();
      await send(const NextRoundRequested()); // not from revealed
      expect(active().session.round, 1);
      await send(const Passed());
      expect(active().session.round, 2);
      expect(active().session.phase, Phase.ready);
      expect(active().session.outcome, isNull);
      expect(active().session.mode, isNull);
      await spinAndFinish();
      await send(const ModeChosen(Mode.dare));
      await send(const NextRoundRequested());
      expect(active().session.round, 3);
      await spinAndFinish();
      await send(const ModeChosen(Mode.dare));
      await send(const Passed());
      expect(active().session.round, 4);
    });
  });

  group('PlayersEdited', () {
    test('ready', () async {
      await startGame(8);
      await send(PlayersEdited(5, nulls(5)));
      expect(active().session.playerCount, 5);
      expect(active().session.id, 'test');
      expect(active().session.round, 1);
      expect(active().orientation, 0);
    });
    test('ignored in revealed and while spinning', () async {
      await startGame(8);
      await send(const SpinRequested());
      await send(PlayersEdited(5, nulls(5)));
      expect(active().session.playerCount, 8);
      await send(const SpinAnimationFinished());
      await send(PlayersEdited(5, nulls(5)));
      expect(active().session.playerCount, 8);
    });
    test('failure keeps old players', () async {
      await startGame(8);
      repo.failWrites = true;
      await send(PlayersEdited(5, nulls(5)));
      expect(active().session.playerCount, 8);
      expect(active().failure, isA<StorageFailure>());
    });
  });

  group('round log', () {
    test('truth/dare logged, pass overwrites, next does not write', () async {
      await startGame(8);
      await spinAndFinish();
      final o = active().session.outcome!;
      await send(const ModeChosen(Mode.truth));
      expect(active().session.log, [
        RoundEntry(
          round: 1,
          taker: o.taker,
          giver: o.giver,
          result: RoundResult.truth,
        ),
      ]);
      await send(const Passed()); // pass after truth overwrites the entry
      expect(active().session.log.single.result, RoundResult.pass);
      expect(active().session.round, 2);
      await spinAndFinish();
      await send(const ModeChosen(Mode.dare));
      repo.calls.clear();
      await send(const NextRoundRequested());
      expect(repo.calls, ['saveRound']);
      expect(active().session.log.map((e) => e.result), [
        RoundResult.pass,
        RoundResult.dare,
      ]);
      expect(repo.stored, active().session);
    });

    test('pass from revealed logs a pass', () async {
      await startGame(8);
      await spinAndFinish();
      await send(const Passed());
      expect(active().session.log.single.result, RoundResult.pass);
    });

    test('log write failure keeps previous state', () async {
      await startGame(8);
      await spinAndFinish();
      repo.failWrites = true;
      await send(const ModeChosen(Mode.truth));
      expect(active().session.log, isEmpty);
      expect(active().session.phase, Phase.revealed);
      await send(const Passed());
      expect(active().session.log, isEmpty);
      expect(active().session.round, 1);
    });
  });

  group('EndConfirmed', () {
    test('no rounds: nothing archived, NoSession', () async {
      await startGame(8);
      await send(const EndConfirmed());
      expect(bloc.state, const NoSession());
      expect(repo.stored, isNull);
      expect(history.rows, isEmpty);
    });
    test('with rounds: SessionSummary, archived', () async {
      await startGame(8);
      await spinAndFinish();
      await send(const ModeChosen(Mode.truth));
      await send(const NextRoundRequested());
      await spinAndFinish();
      await send(const Passed());
      await send(const EndConfirmed());
      final s = bloc.state as SessionSummary;
      expect(s.game.rounds, hasLength(2));
      expect(s.game.playerCount, 8);
      expect(history.rows.single, s.game);
      expect(repo.stored, isNull);
    });
    test('ignored in ResumePrompt', () async {
      repo.stored = stored(4);
      await send(const AppStarted());
      repo.calls.clear();
      await send(const EndConfirmed());
      expect(bloc.state, ResumePrompt(stored(4)));
      expect(repo.calls, isEmpty);
    });
    test('ignored while spinning', () async {
      await startGame(8);
      await send(const SpinRequested());
      await send(const EndConfirmed());
      expect(bloc.state, isA<SessionActive>());
      expect(repo.stored, isNotNull);
    });
    test('failure keeps state', () async {
      await startGame(8);
      repo.failWrites = true;
      await send(const EndConfirmed());
      expect(active().failure, isA<StorageFailure>());
      expect(repo.stored, isNotNull);
    });
  });

  group('SessionSummary', () {
    Future<GameRecord> finishOneRound() async {
      await startGame(4);
      await spinAndFinish();
      await send(const ModeChosen(Mode.dare));
      await send(const EndConfirmed());
      return (bloc.state as SessionSummary).game;
    }

    test('SummaryDismissed -> NoSession', () async {
      await finishOneRound();
      await send(const SummaryDismissed());
      expect(bloc.state, const NoSession());
    });
    test('SummaryDismissed ignored elsewhere', () async {
      await startGame(4);
      final before = bloc.state;
      await send(const SummaryDismissed());
      expect(bloc.state, before);
    });
    test('SessionStarted from summary starts a new game', () async {
      await finishOneRound();
      await send(SessionStarted(4, nulls(4)));
      expect(active().session.round, 1);
      expect(active().session.log, isEmpty);
    });
    test('SessionStarted failure from summary -> NoSession(notice)', () async {
      await finishOneRound();
      repo.failWrites = true;
      await send(SessionStarted(4, nulls(4)));
      expect(bloc.state, const NoSession(notice: "Couldn't save. Try again."));
    });
  });

  group('SessionStarted from ResumePrompt', () {
    test('archives a stored session with rounds', () async {
      repo.stored = stored(4)
          .revealed(const Outcome(taker: 0, giver: 2))
          .chose(Mode.truth);
      await send(const AppStarted());
      await send(SessionStarted(3, nulls(3)));
      expect(active().session.playerCount, 3);
      expect(history.rows, hasLength(1));
    });
    test('a stored session without rounds is just replaced', () async {
      repo.stored = stored(4);
      await send(const AppStarted());
      await send(SessionStarted(3, nulls(3)));
      expect(history.rows, isEmpty);
    });
    test('failure keeps the prompt and shows it', () async {
      repo.stored = stored(4);
      await send(const AppStarted());
      repo.failWrites = true;
      await send(SessionStarted(3, nulls(3)));
      final p = bloc.state as ResumePrompt;
      expect(p.failure, isA<StorageFailure>());
      expect(p.session, stored(4));
    });
  });

  test('SessionLinkOpened', () async {
    repo.stored = stored(4);
    await send(const AppStarted());
    await send(const SessionLinkOpened('other'));
    expect(bloc.state, isA<ResumePrompt>());
    await send(const SessionLinkOpened('test'));
    expect(bloc.state, isA<SessionActive>());
    final before = bloc.state;
    await send(const SessionLinkOpened('test'));
    expect(bloc.state, before);
  });

  test('ReplayRequested', () async {
    await startGame(8);
    await send(const ReplayRequested());
    expect(active().replayCount, 0);
    await spinAndFinish();
    await send(const ReplayRequested());
    expect(active().replayCount, 1);
  });

  for (final n in [2, 3, 5, 7, 59, 60]) {
    test('full loop n=$n keeps store in sync', () async {
      await startGame(n);
      void check() {
        expect(repo.stored, active().session);
        expect(repo.stored!.isValid, isTrue);
      }

      check();
      for (var r = 0; r < 3; r++) {
        await send(const SpinRequested());
        check();
        await send(const SpinAnimationFinished());
        check();
        if (r.isEven) {
          await send(ModeChosen(r == 0 ? Mode.truth : Mode.dare));
          check();
          await send(const NextRoundRequested());
        } else {
          await send(const Passed());
        }
        check();
      }
      expect(active().session.round, 4);
    });
  }
}
