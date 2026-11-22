// TEMP(phase-1): glass proof harness. Delete in Phase 2.
import 'dart:math';

import 'package:flutter/widgets.dart';

class TestPainter extends CustomPainter {
  TestPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final c = size.center(Offset.zero);
    final radius = size.longestSide;
    final rect = Rect.fromCircle(center: c, radius: radius);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = SweepGradient(
          transform: GradientRotation(t * 2 * pi * 6),
          colors: const [
            Color(0xFFFF0000),
            Color(0xFFFFFF00),
            Color(0xFF00FF00),
            Color(0xFF00FFFF),
            Color(0xFF0000FF),
            Color(0xFFFF00FF),
            Color(0xFFFF0000),
          ],
        ).createShader(rect),
    );
    final stripe = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 14;
    final shift = t * 56 * 40;
    for (var x = -size.height; x < size.width + size.height; x += 56) {
      final sx = x + shift % 56;
      canvas.drawLine(
        Offset(sx, 0),
        Offset(sx + size.height, size.height),
        stripe,
      );
    }
  }

  @override
  bool shouldRepaint(TestPainter old) => false;
}
