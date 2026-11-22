import 'dart:math';

import '../entities/session.dart';

const double tau = 2 * pi;

/// 0 = twelve o'clock, clockwise.
double seatAngle(int seat, int n) => tau * seat / n;

double normalizeAngle(double a) => (a % tau + tau) % tau;

/// Even n: one seat. Odd n: the two nearest-opposite seats, floor first.
List<int> oppositeSeats(int n, int taker) => [
  (taker + n ~/ 2) % n,
  if (n.isOdd) (taker + (n + 1) ~/ 2) % n,
];

/// Throws RangeError unless 2 <= n <= 60 (validation must survive release builds).
Outcome pickRoles(int n, Random rng) {
  RangeError.checkValueInInterval(n, 2, 60, 'n');
  final taker = rng.nextInt(n);
  final opp = oppositeSeats(n, taker);
  final giver = opp.length == 1 ? opp[0] : (rng.nextBool() ? opp[0] : opp[1]);
  return Outcome(taker: taker, giver: giver);
}

bool isValidPair(int n, int taker, int giver) =>
    n >= 2 &&
    n <= 60 &&
    taker >= 0 &&
    taker < n &&
    giver >= 0 &&
    giver < n &&
    oppositeSeats(n, taker).contains(giver);

final class SpinPlan {
  const SpinPlan({
    required this.start,
    required this.end,
    required this.turns,
    required this.durationMs,
  });

  /// Radians; [end] is NOT normalised.
  final double start, end;
  final int turns, durationMs;

  @override
  bool operator ==(Object other) =>
      other is SpinPlan &&
      other.start == start &&
      other.end == end &&
      other.turns == turns &&
      other.durationMs == durationMs;

  @override
  int get hashCode => Object.hash(start, end, turns, durationMs);
}

SpinPlan spinPlan({
  required double current,
  required int taker,
  required int n,
  required Random rng,
}) {
  final delta = normalizeAngle(seatAngle(taker, n) - normalizeAngle(current));
  final turns = 5 + rng.nextInt(2);
  return SpinPlan(
    start: current,
    end: current + turns * tau + delta,
    turns: turns,
    durationMs: (4400 + (turns - 5) * 600 + (delta / tau) * 400).round(),
  );
}
