import 'package:flutter/widgets.dart';

import 'dial_painter.dart';

/// Static dial: seat preview (New game) and mini dial (Home card).
class DialPreview extends StatelessWidget {
  const DialPreview({required this.n, this.orientation = 0, super.key});
  final int n;
  final double orientation;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: FittedBox(
      child: SizedBox.square(
        dimension: 240,
        child: CustomPaint(
          painter: DialPainter(
            n: n,
            spin: kAlwaysDismissedAnimation,
            pulse: kAlwaysDismissedAnimation,
            orientation: orientation,
          ),
        ),
      ),
    ),
  );
}
