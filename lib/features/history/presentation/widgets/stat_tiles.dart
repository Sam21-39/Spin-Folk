import 'package:material_ui/material_ui.dart';

import '../../../../app/tokens.dart';
import '../../../session/domain/entities/game_record.dart';

class StatTiles extends StatelessWidget {
  const StatTiles(this.stats, {super.key});
  final GameStats stats;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: _Tile('Truths', stats.truths)),
      const SizedBox(width: Tokens.s8),
      Expanded(child: _Tile('Dares', stats.dares)),
      const SizedBox(width: Tokens.s8),
      Expanded(child: _Tile('Passes', stats.passes)),
    ],
  );
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.n);
  final String label;
  final int n;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Tokens.bgSurface,
        border: Border.all(color: Tokens.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text('$n', style: Tokens.numeral(28)),
          Text(
            label,
            style: Tokens.footnote,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );
}
