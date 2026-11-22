import 'dart:math';
import 'dart:ui';

/// Signed angle from [a] to [b] around the origin, clockwise positive (y down).
double angleDelta(Offset a, Offset b) =>
    atan2(a.dx * b.dy - a.dy * b.dx, a.dx * b.dx + a.dy * b.dy);

/// Angular speed in rad/s of a point at [r] from the centre moving at [v]
/// px/s. 0 inside 8 px.
double angularVelocity(Offset r, Offset v) => r.distanceSquared < 64
    ? 0
    : (r.dx * v.dy - r.dy * v.dx) / r.distanceSquared;

/// Wraps to (-pi, pi].
double wrapPi(double a) {
  const tau = 2 * pi;
  final w = a - tau * (a / tau).roundToDouble();
  return w <= -pi ? w + tau : w;
}
