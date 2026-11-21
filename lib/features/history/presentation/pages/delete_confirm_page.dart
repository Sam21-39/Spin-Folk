import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_navigator.dart';
import '../../../../app/ui.dart';
import '../cubit/history_cubit.dart';
import '../../domain/rules/history_labels.dart';

/// [id] null: Clear all.
class DeleteConfirmPage extends StatelessWidget {
  const DeleteConfirmPage({required this.id, super.key});
  final String? id;

  @override
  Widget build(BuildContext context) {
    final nav = context.read<AppNavigator>();
    final cubit = context.read<HistoryCubit>();
    return BlocBuilder<HistoryCubit, HistoryState>(
      builder: (context, h) {
        final gid = id;
        if (gid == null) {
          final n = h.games.length;
          return ConfirmSheet(
            title: 'Clear all history?',
            body:
                '$n ${n == 1 ? 'game and its round log are' : 'games and their round logs are'} '
                'removed from this iPhone. You can undo for a few seconds.',
            confirmLabel: 'Clear all',
            onConfirm: () {
              cubit.delete([for (final g in h.games) g.id]);
              nav.history();
            },
            onCancel: nav.history,
          );
        }
        final g = h.games.where((g) => g.id == gid).firstOrNull;
        if (g == null) return const SizedBox.shrink();
        final day = dayLabel(
          DateTime.fromMillisecondsSinceEpoch(g.endedAtMs),
          DateTime.now(),
        );
        return ConfirmSheet(
          title: 'Delete this game?',
          body:
              '$day · ${g.playerCount} players · '
              '${roundsLabel(g.rounds.length)}. Its names and round log are '
              'removed from this iPhone. You can undo for a few seconds.',
          confirmLabel: 'Delete game',
          onConfirm: () {
            cubit.delete([gid]);
            nav.history();
          },
          onCancel: () => nav.historyDetail(gid),
        );
      },
    );
  }
}
