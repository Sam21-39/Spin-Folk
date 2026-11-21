import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spinfolk/features/session/domain/rules/selection.dart';

void main() {
  test('pickRoles invariants for every n and 200 seeds', () {
    final seen = <int, Set<int>>{};
    for (var n = 2; n <= 60; n++) {
      for (var seed = 0; seed < 200; seed++) {
        final o = pickRoles(n, Random(seed));
        expect(o.taker, inInclusiveRange(0, n - 1));
        expect(o.giver, isNot(o.taker));
        expect(isValidPair(n, o.taker, o.giver), isTrue);
        if (n.isEven) {
          expect(o.giver, (o.taker + n ~/ 2) % n);
        } else {
          expect(oppositeSeats(n, o.taker), contains(o.giver));
          seen.putIfAbsent(n, () => {}).add(o.giver - o.taker);
        }
        if (n == 2) expect(o.giver, 1 - o.taker);
      }
    }
    // Both odd candidates occur for every odd n tested (distinct offsets mod n).
    for (final n in [3, 5, 7, 59]) {
      final offsets = <int>{};
      for (var seed = 0; seed < 200; seed++) {
        final o = pickRoles(n, Random(seed));
        offsets.add((o.giver - o.taker + n) % n);
      }
      expect(offsets, {n ~/ 2, (n + 1) ~/ 2}, reason: 'n=$n');
    }
  });

  test('out-of-range n throws', () {
    expect(() => pickRoles(1, Random(0)), throwsRangeError);
    expect(() => pickRoles(61, Random(0)), throwsRangeError);
  });

  test('every seat can be taker for n = 7', () {
    final rng = Random(3);
    final takers = {for (var i = 0; i < 2000; i++) pickRoles(7, rng).taker};
    expect(takers, {0, 1, 2, 3, 4, 5, 6});
  });

  test('isValidPair', () {
    expect(isValidPair(8, 0, 0), isFalse);
    expect(isValidPair(8, 0, 8), isFalse);
    expect(isValidPair(8, -1, 3), isFalse);
    expect(isValidPair(8, 0, 3), isFalse);
    expect(isValidPair(8, 0, 4), isTrue);
    expect(isValidPair(1, 0, 0), isFalse);
    expect(isValidPair(61, 0, 30), isFalse);
  });

  test('oppositeSeats', () {
    expect(oppositeSeats(5, 0), [2, 3]);
    expect(oppositeSeats(8, 2), [6]);
    expect(oppositeSeats(2, 0), [1]);
  });
}
