import 'dart:math';
import 'dart:ui';

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spinfolk/features/game/presentation/widgets/dial_painter.dart';
import 'package:spinfolk/features/session/domain/entities/session.dart';
import 'package:spinfolk/features/session/domain/rules/selection.dart';

void main() {
  const still = AlwaysStoppedAnimation<double>(0);

  test('paints every configuration without throwing', () {
    for (final n in [2, 3, 5, 7, 12, 13, 59, 60]) {
      final o = pickRoles(n, Random(1));
      final plan = spinPlan(current: 0, taker: o.taker, n: n, rng: Random(1));
      for (final outcome in [null, o]) {
        for (final spinning in [false, true]) {
          for (final reduce in [false, true]) {
            for (final size in [120.0, 350.0]) {
              final p = DialPainter(
                n: n,
                spin: spinning ? const AlwaysStoppedAnimation(0.5) : still,
                pulse: const AlwaysStoppedAnimation(0.25),
                orientation: 0.3,
                plan: spinning ? plan : null,
                outcome: spinning ? null : outcome,
                reduceMotion: reduce,
              );
              p.paint(Canvas(PictureRecorder()), Size.square(size));
            }
          }
        }
      }
    }
  });

  test('shouldRepaint', () {
    DialPainter make({Outcome? outcome}) => DialPainter(
      n: 8,
      spin: still,
      pulse: still,
      orientation: 0,
      outcome: outcome,
    );
    final a = make(outcome: const Outcome(taker: 0, giver: 4));
    expect(
      a.shouldRepaint(make(outcome: const Outcome(taker: 0, giver: 4))),
      isFalse,
    );
    expect(
      a.shouldRepaint(make(outcome: const Outcome(taker: 1, giver: 5))),
      isTrue,
    );
  });

  test('bottle bounds', () {
    expect(bottleBodyPath().getBounds(), const Rect.fromLTRB(-22, -88, 22, 84));
  });
}
