import 'package:flutter_test/flutter_test.dart';
import 'package:spinfolk/features/history/domain/rules/history_labels.dart';
import 'package:spinfolk/features/session/domain/entities/game_record.dart';
import 'package:spinfolk/features/session/domain/entities/session.dart';

RoundEntry e(int round, int taker, int giver, RoundResult r) =>
    RoundEntry(round: round, taker: taker, giver: giver, result: r);

void main() {
  test('durationLabel', () {
    expect(durationLabel(0), 'under 1 min');
    expect(durationLabel(59999), 'under 1 min');
    expect(durationLabel(60000), '1 min');
    expect(durationLabel(59 * 60000), '59 min');
    expect(durationLabel(60 * 60000), '1 h 00 min');
    expect(durationLabel(65 * 60000), '1 h 05 min');
  });

  test('timeLabel', () {
    expect(timeLabel(DateTime(2026, 1, 1, 21, 41), h24: false), '9:41 PM');
    expect(timeLabel(DateTime(2026, 1, 1, 21, 41), h24: true), '21:41');
    expect(timeLabel(DateTime(2026, 1, 1, 0, 5), h24: false), '12:05 AM');
    expect(timeLabel(DateTime(2026, 1, 1, 0, 5), h24: true), '00:05');
    expect(timeLabel(DateTime(2026, 1, 1, 12, 0), h24: false), '12:00 PM');
  });

  test('dayLabel', () {
    final now = DateTime(2026, 11, 22, 23, 0);
    expect(dayLabel(DateTime(2026, 11, 22, 18), now), 'Tonight');
    expect(dayLabel(DateTime(2026, 11, 22, 17, 59), now), 'Today');
    expect(dayLabel(DateTime(2026, 11, 22, 0, 0), now), 'Today');
    expect(dayLabel(DateTime(2026, 11, 21, 21), now), 'Sat 21 Nov');
    expect(dayLabel(DateTime(2025, 11, 21, 21), now), 'Fri 21 Nov 2025');
  });

  test('groupLabel boundaries', () {
    final now = DateTime(2026, 11, 22, 0, 30);
    expect(groupLabel(DateTime(2026, 11, 22, 0, 0), now), 'TODAY');
    expect(groupLabel(DateTime(2026, 11, 21, 23, 59), now), 'THIS WEEK');
    expect(groupLabel(DateTime(2026, 11, 16, 12), now), 'THIS WEEK'); // 6 days
    expect(groupLabel(DateTime(2026, 11, 15, 12), now), 'NOVEMBER'); // 7 days
    expect(groupLabel(DateTime(2026, 10, 3), now), 'OCTOBER');
    expect(groupLabel(DateTime(2025, 10, 3), now), 'OCTOBER 2025');
    // Year change: 3 days ago across New Year is still this week.
    expect(
      groupLabel(DateTime(2025, 12, 30), DateTime(2026, 1, 2)),
      'THIS WEEK',
    );
  });

  test('circleLabel', () {
    List<Player> ps(int n, Map<int, String> names) => [
      for (var i = 0; i < n; i++) Player(seat: i, name: names[i]),
    ];
    expect(circleLabel(ps(6, {})), 'Players 1–6');
    expect(circleLabel(ps(60, {})), 'Players 1–60');
    expect(circleLabel(ps(4, {1: 'Riya'})), 'Riya +3');
    expect(circleLabel(ps(2, {0: 'A', 1: 'B'})), 'A, B');
    expect(circleLabel(ps(3, {0: 'A', 1: 'B', 2: 'C'})), 'A, B, C');
    expect(circleLabel(ps(4, {0: 'A', 1: 'B', 2: 'C', 3: 'D'})), 'A, B, C +1');
    expect(circleLabel(ps(60, {5: 'X'})), 'X +59');
  });

  test('roundsLabel, resultLabel', () {
    expect(roundsLabel(1), '1 round');
    expect(roundsLabel(0), '0 rounds');
    expect(roundsLabel(12), '12 rounds');
    expect(resultLabel(RoundResult.truth), 'Truth');
    expect(resultLabel(RoundResult.dare), 'Dare');
    expect(resultLabel(RoundResult.pass), 'Passed · no penalty');
  });

  group('GameStats.of', () {
    test('empty', () {
      final s = GameStats.of(const []);
      expect((s.truths, s.dares, s.passes), (0, 0, 0));
      expect(s.topTaker, isNull);
      expect(s.topGiver, isNull);
    });
    test('all pass: taker counts, nobody asked', () {
      final s = GameStats.of([
        e(1, 3, 0, RoundResult.pass),
        e(2, 3, 1, RoundResult.pass),
      ]);
      expect(s.passes, 2);
      expect(s.topTaker, (seat: 3, count: 2));
      expect(s.topGiver, isNull);
    });
    test('ties go to the lowest seat', () {
      final s = GameStats.of([
        e(1, 4, 0, RoundResult.truth),
        e(2, 2, 1, RoundResult.dare),
        e(3, 4, 1, RoundResult.pass),
        e(4, 2, 0, RoundResult.truth),
      ]);
      expect((s.truths, s.dares, s.passes), (2, 1, 1));
      expect(s.topTaker, (seat: 2, count: 2));
      expect(s.topGiver, (seat: 0, count: 2));
    });
  });
}
