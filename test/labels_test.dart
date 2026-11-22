import 'package:flutter_test/flutter_test.dart';
import 'package:spinfolk/features/session/domain/entities/session.dart';
import 'package:spinfolk/features/session/domain/rules/labels.dart';

Session sess({
  List<String?> names = const [null, null, null, null],
  Phase phase = Phase.ready,
  Outcome? outcome,
  Mode? mode,
  int round = 1,
}) => Session(
  id: 'x',
  startedAtMs: 0,
  players: [
    for (var i = 0; i < names.length; i++) Player(seat: i, name: names[i]),
  ],
  phase: phase,
  outcome: outcome,
  mode: mode,
  round: round,
);

void main() {
  test('normalizeName', () {
    expect(normalizeName(null), isNull);
    expect(normalizeName(''), isNull);
    expect(normalizeName('  '), isNull);
    expect(normalizeName(' Riya '), 'Riya');
    expect(normalizeName('a' * 45)!.runes.length, 40);
    final astral = '\u{1F600}' * 41;
    final out = normalizeName(astral)!;
    expect(out.runes.length, 40);
    expect(out, '\u{1F600}' * 40); // not split mid surrogate pair
  });

  test('displayLabel', () {
    expect(displayLabel(const Player(seat: 6)), 'Player 7');
    expect(displayLabel(const Player(seat: 6, name: 'Riya')), 'Riya · P7');
  });

  test('spokenName', () {
    final s = sess(names: ['Riya', 'Sam', 'sam', null]);
    expect(spokenName(s, 0), 'Riya');
    expect(spokenName(s, 1), 'Player 2');
    expect(spokenName(s, 2), 'Player 3');
    expect(spokenName(s, 3), 'Player 4');
  });

  test('speechLine', () {
    const o = Outcome(taker: 0, giver: 2);
    final names = ['Riya', null, 'Sam', null];
    expect(speechLine(sess(names: names)), isNull);
    expect(
      speechLine(sess(names: names, phase: Phase.revealed, outcome: o)),
      'Sam, give a challenge to Riya.',
    );
    expect(
      speechLine(
        sess(
          names: names,
          phase: Phase.challenge,
          outcome: o,
          mode: Mode.truth,
        ),
      ),
      'Riya chose Truth.',
    );
    expect(
      speechLine(
        sess(names: names, phase: Phase.challenge, outcome: o, mode: Mode.dare),
      ),
      'Riya chose Dare.',
    );
  });

  test('Session.isValid', () {
    const o = Outcome(taker: 0, giver: 2);
    expect(sess().isValid, isTrue);
    expect(sess(phase: Phase.revealed, outcome: o).isValid, isTrue);
    expect(
      sess(phase: Phase.challenge, outcome: o, mode: Mode.dare).isValid,
      isTrue,
    );
    // violations
    expect(sess(names: [null]).isValid, isFalse); // < 2 players
    expect(sess(names: List.filled(61, null)).isValid, isFalse);
    expect(sess(round: 0).isValid, isFalse);
    expect(sess(names: [' x ', null]).isValid, isFalse); // not normalised
    expect(sess(names: ['', null]).isValid, isFalse);
    expect(sess(outcome: o).isValid, isFalse); // ready with outcome
    expect(sess(mode: Mode.truth).isValid, isFalse); // ready with mode
    expect(sess(phase: Phase.revealed).isValid, isFalse);
    expect(
      sess(phase: Phase.revealed, outcome: o, mode: Mode.truth).isValid,
      isFalse,
    );
    expect(sess(phase: Phase.challenge, outcome: o).isValid, isFalse);
    expect(
      sess(
        phase: Phase.revealed,
        outcome: const Outcome(taker: 0, giver: 1),
      ).isValid,
      isFalse,
    ); // not opposite for n=4
    const bad = Session(
      id: 'x',
      startedAtMs: 0,
      players: [Player(seat: 1), Player(seat: 0)],
    );
    expect(bad.isValid, isFalse);
  });
}
