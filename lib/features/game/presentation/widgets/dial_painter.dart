import 'dart:math';

import 'package:flutter/widgets.dart';

import '../../../../app/tokens.dart';
import '../../../session/domain/entities/session.dart';
import '../../../session/domain/rules/selection.dart';

/// Bottle body in its own units: neck up, spans y -88..84, x -22..22.
Path bottleBodyPath() => Path()
  ..moveTo(-8, -88)
  ..lineTo(8, -88)
  ..lineTo(8, -40)
  ..cubicTo(8, -24, 22, -18, 22, 0)
  ..lineTo(22, 72)
  ..quadraticBezierTo(22, 84, 10, 84)
  ..lineTo(-10, 84)
  ..quadraticBezierTo(-22, 84, -22, 72)
  ..lineTo(-22, 0)
  ..cubicTo(-22, -18, -8, -24, -8, -40)
  ..close();

Offset _dir(double a) => Offset(sin(a), -cos(a));

class DialPainter extends CustomPainter {
  DialPainter({
    required this.n,
    required this.spin, // 0..1 while spinning
    required this.pulse, // 0..1 after reveal
    required this.orientation, // resting bottle angle
    this.plan, // non-null only while spinning
    this.outcome, // non-null only when revealed AND not spinning
    this.reduceMotion = false,
  }) : super(repaint: Listenable.merge([spin, pulse]));

  final int n;
  final Animation<double> spin, pulse;
  final double orientation;
  final SpinPlan? plan;
  final Outcome? outcome;
  final bool reduceMotion;

  // Built once per painter instance, never per frame.
  Path? _ring;
  double? _ringRadius;
  final Map<String, TextPainter> _text = {};

  @override
  bool shouldRepaint(DialPainter old) =>
      old.n != n ||
      old.orientation != orientation ||
      old.plan != plan ||
      old.outcome != outcome ||
      old.reduceMotion != reduceMotion;

  TextPainter _tp(String text, double size, Color color) =>
      _text.putIfAbsent('$text|$size|${color.toARGB32()}', () {
        return TextPainter(
          text: TextSpan(
            text: text,
            style: Tokens.numeral(size, color: color),
          ),
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.noScaling, // dial labels ignore text scale
        )..layout();
      });

  void _label(Canvas canvas, Offset at, String text, double size, Color c) {
    final tp = _tp(text, size, c);
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  /// 1 + 0.18 sin(pi * ((pulse*2) % 1)); exactly 1 at 0 and 1.
  double get _pulseScale {
    if (reduceMotion) return 1;
    final p = pulse.value;
    if (p <= 0 || p >= 1) return 1;
    return 1 + 0.18 * sin(pi * ((p * 2) % 1));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final side = size.shortestSide;
    final r = side / 2 - 4;
    final k = (r / 146).clamp(0.75, 1.2);

    // 1. disc
    canvas
      ..drawCircle(c, r, Paint()..color = Tokens.bgSurface)
      ..drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Tokens.line,
      );

    // 2. inner dashed ring
    final ringR = r - 50 * k;
    if (ringR > 0) {
      if (_ring == null || _ringRadius != ringR) {
        final segs = max(8, (2 * pi * ringR / 8).floor());
        final p = Path();
        for (var i = 0; i < segs; i++) {
          final a0 = 2 * pi * i / segs;
          p.addArc(
            Rect.fromCircle(center: Offset.zero, radius: ringR),
            a0 - pi / 2,
            2 / ringR,
          );
        }
        _ring = p;
        _ringRadius = ringR;
      }
      canvas
        ..save()
        ..translate(c.dx, c.dy)
        ..drawPath(
          _ring!,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Tokens.line,
        )
        ..restore();
    }

    // 3. seats
    final o = outcome;
    Color? roleOf(int i) => o == null
        ? null
        : (i == o.taker ? Tokens.taker : (i == o.giver ? Tokens.giver : null));
    final ps = _pulseScale;
    if (n <= 12) {
      _discs(canvas, c, r, k, roleOf, ps);
    } else {
      _ticks(canvas, c, r, k, roleOf, ps);
    }

    // 4. odd-N arc
    final s = 0.62 * r / 96;
    if (o != null && n.isOdd) _arc(canvas, c, 78 * s, o);

    // 5. bottle
    final p = plan;
    if (p != null && reduceMotion) {
      _bottle(canvas, c, s, p.start, 1 - spin.value);
      _bottle(canvas, c, s, p.end, spin.value);
    } else {
      final angle = p == null
          ? orientation
          : p.start +
                (p.end - p.start) * Tokens.spinCurve.transform(spin.value);
      _bottle(canvas, c, s, angle, 1);
    }

    // 6. pin
    canvas.drawCircle(c, 3 * k, Paint()..color = Tokens.textPrimary);
  }

  void _discs(
    Canvas canvas,
    Offset c,
    double r,
    double k,
    Color? Function(int) roleOf,
    double ps,
  ) {
    for (var i = 0; i < n; i++) {
      final at = c + _dir(seatAngle(i, n)) * (r - 24 * k);
      final role = roleOf(i);
      canvas.save();
      if (role != null) {
        canvas
          ..translate(at.dx, at.dy)
          ..scale(ps)
          ..translate(-at.dx, -at.dy)
          ..drawCircle(
            at,
            25 * k,
            Paint()..color = role.withValues(alpha: 0.22),
          )
          ..drawCircle(at, 18 * k, Paint()..color = role);
        _label(canvas, at, '${i + 1}', 14 * k, Tokens.bgBase);
      } else {
        canvas
          ..drawCircle(at, 15 * k, Paint()..color = Tokens.bgRaised)
          ..drawCircle(
            at,
            15 * k,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = Tokens.line,
          );
        _label(canvas, at, '${i + 1}', 14 * k, Tokens.textPrimary);
      }
      canvas.restore();
    }
  }

  void _ticks(
    Canvas canvas,
    Offset c,
    double r,
    double k,
    Color? Function(int) roleOf,
    double ps,
  ) {
    final o = outcome;
    final labelR = r - 42 * k;
    for (var i = 0; i < n; i++) {
      final d = _dir(seatAngle(i, n));
      final role = roleOf(i);
      final fifth = i % 5 == 0;
      final len = role != null ? 22 * k : (fifth ? 13 * k : 8 * k);
      final outer = c + d * (r - 4);
      canvas.drawLine(
        outer,
        outer - d * len,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = role != null ? 4 : 2
          ..color = role ?? (fifth ? Tokens.textSecondary : Tokens.line),
      );
      final at = c + d * labelR;
      if (role != null) {
        canvas
          ..save()
          ..translate(at.dx, at.dy)
          ..scale(ps)
          ..translate(-at.dx, -at.dy)
          ..drawCircle(
            at,
            13 * k,
            Paint()..color = role.withValues(alpha: 0.22),
          );
        _label(canvas, at, '${i + 1}', 12 * k, role);
        canvas.restore();
      } else if (fifth) {
        final near =
            o != null &&
            [o.taker, o.giver].any((s) {
              final diff = (s - i).abs();
              return min(diff, n - diff) <= 1;
            });
        if (!near) _label(canvas, at, '${i + 1}', 10 * k, Tokens.textTertiary);
      }
    }
  }

  void _arc(Canvas canvas, Offset c, double radius, Outcome o) {
    final base = seatAngle(o.taker, n) + pi;
    var diff = (seatAngle(o.giver, n) - base) % tau;
    if (diff > pi) diff -= tau;
    final count = max(1, (diff.abs() * radius / 7).floor());
    final paint = Paint()..color = Tokens.giver;
    for (var j = 0; j <= count; j++) {
      canvas.drawCircle(c + _dir(base + diff * j / count) * radius, 1.5, paint);
    }
  }

  void _bottle(Canvas canvas, Offset c, double s, double angle, double alpha) {
    if (alpha <= 0) return;
    if (alpha < 1) {
      canvas.saveLayer(
        Rect.fromCircle(center: c, radius: 100 * s + 8),
        Paint()..color = Color.fromRGBO(255, 255, 255, alpha),
      );
    }
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(angle)
      ..scale(s);
    final body = bottleBodyPath();
    canvas
      ..drawPath(body, Paint()..color = Tokens.bottleFill)
      ..drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round
          ..color = Tokens.bottleStroke,
      )
      ..drawRRect(
        RRect.fromLTRBR(-10, -98, 10, -88, const Radius.circular(3)),
        Paint()..color = Tokens.taker,
      )
      ..drawRRect(
        RRect.fromLTRBR(-14, 78, 14, 84, const Radius.circular(3)),
        Paint()..color = Tokens.giver,
      )
      ..drawLine(
        const Offset(-12, 6),
        const Offset(-12, 60),
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 5
          ..color = const Color(0x59FFFFFF),
      )
      ..restore();
    if (alpha < 1) canvas.restore();
  }
}
