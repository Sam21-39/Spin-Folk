import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spinfolk/features/session/domain/rules/selection.dart';

void main() {
  test('seatAngle and normalizeAngle', () {
    for (final n in [2, 8, 60]) {
      expect(seatAngle(0, n), 0);
    }
    expect(seatAngle(2, 8), pi / 2);
    expect(normalizeAngle(-pi / 2), closeTo(3 * pi / 2, 1e-12));
    expect(normalizeAngle(5 * tau + 1), closeTo(1, 1e-9));
    expect(normalizeAngle(0), 0);
  });

  test('chained plans with repeated taker add no extra turn', () {
    const n = 7;
    var cur = seatAngle(3, n);
    for (var i = 0; i < 5; i++) {
      final plan = spinPlan(current: cur, taker: 3, n: n, rng: Random(i));
      expect(plan.end - plan.start, closeTo(plan.turns * tau, 1e-9));
      cur = seatAngle(3, n); // what _finishSpin now stores
    }
  });

  test('spinPlan lands on the taker seat', () {
    for (final n in [2, 3, 5, 7, 8, 59, 60]) {
      for (var seed = 0; seed < 20; seed++) {
        for (final current in [0.0, 1.0, 6.2, 13.7]) {
          final rng = Random(seed);
          final taker = rng.nextInt(n);
          final plan = spinPlan(current: current, taker: taker, n: n, rng: rng);
          final diff = (normalizeAngle(plan.end) - seatAngle(taker, n)).abs();
          expect(diff < 1e-9 || (tau - diff) < 1e-9, isTrue);
          expect(plan.end - plan.start, inInclusiveRange(5 * tau, 7 * tau));
          expect(plan.end - plan.start, lessThan(7 * tau));
          expect(plan.turns, anyOf(5, 6));
          final delta = normalizeAngle(
            seatAngle(taker, n) - normalizeAngle(current),
          );
          expect(
            plan.durationMs,
            (4400 + (plan.turns - 5) * 600 + (delta / tau) * 400).round(),
          );
          expect(plan.durationMs, inInclusiveRange(4400, 5400));
          expect(plan.start, current);
        }
      }
    }
  });
}
