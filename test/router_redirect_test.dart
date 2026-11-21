import 'package:flutter_test/flutter_test.dart';
import 'package:spinfolk/app/router.dart';
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

void main() {
  const paths = [
    '/new',
    '/names',
    '/resume',
    '/game',
    '/game/settings',
    '/game/end',
  ];

  test('SessionLoading never redirects', () {
    for (final p in paths) {
      expect(r(const SessionLoading(), p), isNull);
    }
  });

  test('NoSession', () {
    for (final p in paths) {
      expect(
        r(const NoSession(), p),
        p == '/new' || p == '/names' ? null : '/new',
      );
    }
    expect(r(const NoSession(), '/game/settings'), '/new');
  });

  test('ResumePrompt', () {
    final s = ResumePrompt(sess(Phase.ready));
    for (final p in paths) {
      expect(r(s, p), p == '/resume' || p == '/game/end' ? null : '/resume');
    }
  });

  test('SessionActive', () {
    final s = SessionActive(session: sess(Phase.ready));
    for (final p in ['/game', '/game/settings', '/game/end']) {
      expect(r(s, p), isNull);
    }
    expect(r(s, '/new'), '/game');
    expect(r(s, '/names'), '/game');
    expect(r(s, '/resume'), '/game');
    expect(r(s, '/new?edit=1'), isNull);
    expect(r(s, '/names?edit=1'), isNull);
  });

  test('edit only when ready and not spinning', () {
    final revealed = SessionActive(session: sess(Phase.revealed));
    expect(r(revealed, '/new?edit=1'), '/game');
    final challenge = SessionActive(session: sess(Phase.challenge));
    expect(r(challenge, '/names?edit=1'), '/game');
    final spinning = SessionActive(
      session: sess(Phase.revealed),
      spinning: true,
      spinPlan: const SpinPlan(start: 0, end: 1, turns: 5, durationMs: 4400),
    );
    expect(r(spinning, '/names?edit=1'), '/game');
    expect(r(spinning, '/new?edit=0'), '/game');
  });
}
