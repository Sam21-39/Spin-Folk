import 'package:flutter/widgets.dart';

import '../../../../app/tokens.dart';
import '../../../session/domain/entities/session.dart';
import '../../../session/domain/rules/labels.dart';

class RoleCards extends StatelessWidget {
  const RoleCards({required this.session, super.key});
  final Session session;

  @override
  Widget build(BuildContext context) {
    final o = session.outcome!;
    final taker = session.players[o.taker];
    final giver = session.players[o.giver];
    final stacked =
        taker.name != null ||
        giver.name != null ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final t = _Card(
      player: taker,
      isTaker: true,
      subtitle: stacked ? 'Picks Truth or Dare' : 'Picks',
    );
    final g = _Card(
      player: giver,
      isTaker: false,
      subtitle: stacked ? 'Gives the challenge' : 'Asks',
    );
    if (stacked) {
      return Column(children: [t, const SizedBox(height: 10), g]);
    }
    return Row(
      children: [
        Expanded(child: t),
        const SizedBox(width: 10),
        Expanded(child: g),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.player,
    required this.isTaker,
    required this.subtitle,
  });
  final Player player;
  final bool isTaker;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final color = isTaker ? Tokens.taker : Tokens.giver;
    final role = isTaker ? 'Taker' : 'Giver';
    final named = player.name != null;
    return Semantics(
      label: '$role, ${displayLabel(player)}',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: Tokens.bgSurface,
          border: Border.all(color: Tokens.line),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: CustomPaint(
                size: const Size.square(20),
                painter: _RoleIcon(isTaker),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    named
                        ? '${role.toUpperCase()} · P${player.seat + 1}'
                        : role.toUpperCase(),
                    style: Tokens.caption.copyWith(color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (named)
                    Text(
                      player.name!,
                      style: Tokens.numeral(22),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Player ${player.seat + 1}',
                        style: Tokens.numeral(22),
                        maxLines: 1,
                      ),
                    ),
                  Text(
                    subtitle,
                    style: Tokens.subhead.copyWith(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleIcon extends CustomPainter {
  _RoleIcon(this.up);
  final bool up;

  @override
  bool shouldRepaint(_RoleIcon old) => old.up != up;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final paint = Paint()
      ..color = Tokens.bgBase
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    if (up) {
      canvas.drawPath(
        Path()
          ..moveTo(12, 3)
          ..lineTo(12, 21)
          ..moveTo(6, 9)
          ..lineTo(12, 3)
          ..lineTo(18, 9),
        paint,
      );
    } else {
      canvas
        ..drawLine(const Offset(12, 3), const Offset(12, 15), paint)
        ..drawRRect(
          RRect.fromLTRBR(6, 17, 18, 21, const Radius.circular(2)),
          Paint()..color = Tokens.bgBase,
        );
    }
  }
}
