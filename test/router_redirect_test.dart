import 'package:flutter_test/flutter_test.dart';
import 'package:spinfolk/app/router.dart';
import 'package:spinfolk/features/session/domain/entities/game_record.dart';
import 'package:spinfolk/features/session/domain/entities/session.dart';
import 'package:spinfolk/features/session/domain/rules/selection.dart';
import 'package:spinfolk/features/session/presentation/bloc/session_bloc.dart';

Session sess(Phase phase) => Session(
  id: 'x',
  startedAtMs: 0,
  players: [for (var i = 0; i < 8; i++) Player(seat: i)],
  phase: phase,
  outcome: phase == Phase.ready ? null : const Outcome(taker: 0, giver: 4),
  mode: phase == Phase.challenge ? Mode.truth : null,
);

String? r(SessionState s, String uri) => sessionRedirect(s, Uri.parse(uri));

const _game = GameRecord(
  id: 'g',
  startedAtMs: 0,
  endedAtMs: 1,
  players: [],
  rounds: [],
);

void main() {
  const hub = ['/', '/new', '/names', '/new?edit=1', '/names?edit=1'];
  const history = [
    '/history',
    '/history/clear',
    '/history/abc',
    '/history/abc/delete',
  ];
  const game = ['/game', '/game/settings', '/game/log', '/game/end'];
  const all = [...hub, ...history, '/summary', ...game, '/resume', '/nope'];

  final states = <String, SessionState>{
    'loading': const SessionLoading(),
    'none': const NoSession(),
    'resume': ResumePrompt(sess(Phase.ready)),
    'summary': const SessionSummary(_game),
    'ready': SessionActive(session: sess(Phase.ready)),
    'revealed': SessionActive(session: sess(Phase.revealed)),
    'challenge': SessionActive(session: sess(Phase.challenge)),
    'spinning': SessionActive(
      session: sess(Phase.revealed),
      spinning: true,
      spinPlan: const SpinPlan(start: 0, end: 1, turns: 5, durationMs: 4400),
    ),
  };

  test('malformed history paths are not history', () {
    for (final p in ['/history/a/b/c', '/history/x/delete/y']) {
      expect(r(const NoSession(), p), '/', reason: p);
    }
  });

  test('SessionLoading never redirects', () {
    for (final p in all) {
      expect(r(const SessionLoading(), p), isNull);
    }
  });

  for (final name in ['none', 'resume']) {
    test('hub state: $name', () {
      for (final p in [...hub, ...history]) {
        expect(r(states[name]!, p), isNull, reason: p);
      }
      for (final p in ['/summary', ...game, '/resume', '/nope']) {
        expect(r(states[name]!, p), '/', reason: p);
      }
    });
  }

  test('SessionSummary', () {
    const s = SessionSummary(_game);
    for (final p in ['/summary', ...history]) {
      expect(r(s, p), isNull, reason: p);
    }
    for (final p in [...hub, ...game, '/resume', '/nope']) {
      expect(r(s, p), '/summary', reason: p);
    }
  });

  test('SessionActive', () {
    final s = states['ready']!;
    for (final p in [...game, '/new?edit=1', '/names?edit=1']) {
      expect(r(s, p), isNull, reason: p);
    }
    for (final p in [
      '/',
      '/new',
      '/names',
      ...history,
      '/summary',
      '/resume',
    ]) {
      expect(r(s, p), '/game', reason: p);
    }
  });

  test('edit only when ready and not spinning', () {
    for (final k in ['revealed', 'challenge', 'spinning']) {
      expect(r(states[k]!, '/new?edit=1'), '/game', reason: k);
      expect(r(states[k]!, '/names?edit=1'), '/game', reason: k);
    }
    expect(r(states['ready']!, '/new?edit=0'), '/game');
  });

  test('no cell returns a location it rejects', () {
    for (final e in states.entries) {
      for (final p in all) {
        final to = r(e.value, p);
        if (to != null) {
          expect(r(e.value, to), isNull, reason: '${e.key} $p -> $to');
        }
      }
    }
  });
}
