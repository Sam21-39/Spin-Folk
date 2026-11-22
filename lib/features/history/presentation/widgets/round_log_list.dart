import 'package:material_ui/material_ui.dart';

import '../../../../app/tokens.dart';
import '../../../session/domain/entities/session.dart';
import '../../../session/domain/rules/labels.dart';
import '../../domain/rules/history_labels.dart';

/// Newest first. A plain Column: the parent scrolls.
class RoundLogList extends StatelessWidget {
  const RoundLogList({required this.players, required this.rounds, super.key});
  final List<Player> players;
  final List<RoundEntry> rounds;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Tokens.bgSurface,
      border: Border.all(color: Tokens.line),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      children: [
        for (final e in rounds.reversed) ...[
          _Row(players: players, e: e),
          if (e != rounds.first)
            const ColoredBox(
              color: Tokens.line,
              child: SizedBox(height: 1, width: double.infinity),
            ),
        ],
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.players, required this.e});
  final List<Player> players;
  final RoundEntry e;

  @override
  Widget build(BuildContext context) {
    final giver = shortLabel(playerAt(players, e.giver));
    final taker = shortLabel(playerAt(players, e.taker));
    final pass = e.result == RoundResult.pass;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '${e.round}',
                style: Tokens.numeral(15, color: Tokens.textTertiary),
              ),
            ),
            Expanded(
              child: pass
                  ? Text(
                      resultLabel(e.result),
                      style: const TextStyle(
                        color: Tokens.textTertiary,
                        fontSize: 15,
                      ),
                    )
                  : Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: giver,
                            style: const TextStyle(color: Tokens.giver),
                          ),
                          const TextSpan(
                            text: ' → ',
                            style: TextStyle(color: Tokens.textTertiary),
                          ),
                          TextSpan(
                            text: taker,
                            style: const TextStyle(color: Tokens.taker),
                          ),
                        ],
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            if (!pass) ...[
              const SizedBox(width: Tokens.s8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: const ShapeDecoration(
                  color: Tokens.bgRaised,
                  shape: StadiumBorder(),
                ),
                child: Text(
                  resultLabel(e.result),
                  style: const TextStyle(
                    color: Tokens.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
