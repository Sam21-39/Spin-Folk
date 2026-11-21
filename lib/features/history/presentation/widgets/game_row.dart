import 'package:material_ui/material_ui.dart';

import '../../../../app/tokens.dart';
import '../../../session/domain/entities/game_record.dart';
import '../../domain/rules/history_labels.dart';

class GameRow extends StatelessWidget {
  const GameRow({
    required this.game,
    required this.now,
    required this.h24,
    required this.onTap,
    this.divider = false,
    super.key,
  });
  final GameRecord game;
  final DateTime now;
  final bool h24;
  final VoidCallback onTap;

  /// 1-px line above the row; inside the row so it collapses with it.
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final ended = DateTime.fromMillisecondsSinceEpoch(game.endedAtMs);
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: Tokens.touch),
            decoration: BoxDecoration(
              color: Tokens.bgSurface,
              border: divider
                  ? const Border(top: BorderSide(color: Tokens.line))
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${dayLabel(ended, now)} · '
                        '${timeLabel(ended, h24: h24)}',
                        style: Tokens.headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${game.playerCount} players · '
                        '${roundsLabel(game.rounds.length)} · '
                        '${durationLabel(game.durationMs)}',
                        style: const TextStyle(
                          color: Tokens.textSecondary,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        circleLabel(game.players),
                        style: Tokens.footnote,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Tokens.s8),
                const ExcludeSemantics(
                  child: Text(
                    '›',
                    style: TextStyle(color: Tokens.textTertiary, fontSize: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
