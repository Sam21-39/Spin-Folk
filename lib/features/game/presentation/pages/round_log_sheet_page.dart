import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_navigator.dart';
import '../../../../app/tokens.dart';
import '../../../../app/ui.dart';
import '../../../history/domain/rules/history_labels.dart';
import '../../../history/presentation/widgets/round_log_list.dart';
import '../../../session/domain/entities/game_record.dart';
import '../../../session/presentation/bloc/session_bloc.dart';

class RoundLogSheetPage extends StatelessWidget {
  const RoundLogSheetPage({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.read<AppNavigator>();
    return BlocBuilder<SessionBloc, SessionState>(
      builder: (context, st) {
        if (st is! SessionActive) return const SizedBox.shrink();
        final log = st.session.log;
        final s = GameStats.of(log);
        return SheetFrame(
          title: 'Round log',
          subtitle:
              '${roundsLabel(log.length)} · ${s.truths} Truth · '
              '${s.dares} Dare · ${s.passes} pass',
          onDone: nav.game,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: log.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: Tokens.s32),
                        child: Center(
                          child: Text(
                            'No rounds yet. Spin to start.',
                            style: TextStyle(
                              color: Tokens.textSecondary,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      )
                    : RoundLogList(players: st.session.players, rounds: log),
              ),
            ),
          ],
        );
      },
    );
  }
}
