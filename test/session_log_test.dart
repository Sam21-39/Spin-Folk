import 'package:flutter_test/flutter_test.dart';
import 'package:spinfolk/features/session/domain/entities/session.dart';

Session base() => Session(
  id: 'x',
  startedAtMs: 0,
  players: [for (var i = 0; i < 8; i++) Player(seat: i)],
);

void main() {
  test('chose then passed leaves one pass entry', () {
    final s = base()
        .revealed(const Outcome(taker: 1, giver: 5))
        .chose(Mode.truth)
        .passed();
    expect(s.log, hasLength(1));
    expect(s.log.single.result, RoundResult.pass);
    expect(s.round, 2);
    expect(s.isValid, isTrue);
  });

  test('log survives nextRound and withPlayers, entry for round is last', () {
    var s = base().revealed(const Outcome(taker: 1, giver: 5)).chose(Mode.dare);
    s = s
        .nextRound()
        .revealed(const Outcome(taker: 2, giver: 6))
        .chose(Mode.truth);
    expect(s.log.map((e) => e.round), [1, 2]);
    expect(s.withPlayers(s.players).log, s.log);
  });

  test('isValid rejects bad log entries', () {
    RoundEntry e(int r, int t, int g) =>
        RoundEntry(round: r, taker: t, giver: g, result: RoundResult.pass);
    Session withLog(List<RoundEntry> l) => Session(
      id: 'x',
      startedAtMs: 0,
      players: base().players,
      round: 2,
      log: l,
    );
    expect(withLog([e(1, 0, 4)]).isValid, isTrue);
    expect(withLog([e(3, 0, 4)]).isValid, isFalse); // round > session.round
    expect(withLog([e(1, 2, 2)]).isValid, isFalse);
    expect(withLog([e(1, 0, 60)]).isValid, isFalse);
    expect(withLog([e(2, 0, 4), e(1, 0, 4)]).isValid, isFalse);
    expect(withLog([e(1, 0, 4), e(1, 0, 4)]).isValid, isFalse);
  });
}
