import 'dart:math';

import 'package:flutter/widgets.dart';

import '../features/game/presentation/widgets/dial_painter.dart';
import 'tokens.dart';

class LogoMark extends StatelessWidget {
  const LogoMark({this.size = 44, this.rotation = pi / 4, super.key});
  final double size, rotation;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _LogoPainter(rotation),
    ),
  );
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.rotation);
  final double rotation;

  @override
  bool shouldRepaint(_LogoPainter old) => old.rotation != rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 100;
    final c = Offset(50 * u, 50 * u);
    const step = pi / 4;
    final taker = (rotation / step).round() % 8;
    final giver = (taker + 4) % 8;
    for (var i = 0; i < 8; i++) {
      final a = i * step;
      final at = c + Offset(sin(a), -cos(a)) * (36 * u);
      final role = i == taker
          ? Tokens.taker
          : (i == giver ? Tokens.giver : null);
      canvas.drawCircle(
        at,
        (role == null ? 4.6 : 6.2) * u,
        Paint()..color = role ?? Tokens.dot,
      );
    }
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(rotation)
      ..scale(0.27 * u)
      ..drawPath(bottleBodyPath(), Paint()..color = const Color(0xF2E8EEF7))
      ..drawRRect(
        RRect.fromLTRBR(-10, -100, 10, -88, const Radius.circular(4)),
        Paint()..color = Tokens.taker,
      )
      ..drawRRect(
        RRect.fromLTRBR(-22, 70, 22, 84, const Radius.circular(6)),
        Paint()..color = Tokens.giver,
      )
      ..restore();
  }
}
