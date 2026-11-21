import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_navigator.dart';
import '../../../../app/logo_mark.dart';
import '../../../../app/tokens.dart';
import '../../../../app/ui.dart';
import '../../../../platform/native_action_bar.dart';
import '../../domain/entities/session.dart';
import '../../domain/rules/labels.dart';
import '../bloc/session_bloc.dart';

class ResumePage extends StatelessWidget {
  const ResumePage({super.key});

  // D19: the schema keeps no history, so describe the current round.
  static String status(Session s) {
    final o = s.outcome;
    if (o == null) return 'Ready for the next spin.';
    final taker = displayLabel(s.players[o.taker]);
    final giver = displayLabel(s.players[o.giver]);
    return switch (s.phase) {
      Phase.ready => 'Ready for the next spin.',
      Phase.revealed => 'This round: $giver gives $taker a challenge.',
      Phase.challenge =>
        'This round: $giver gave $taker a '
            '${s.mode == Mode.dare ? 'Dare' : 'Truth'}.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<SessionBloc>();
    final nav = context.read<AppNavigator>();
    final sc = barScale(context);
    return Scaffold(
      backgroundColor: Tokens.bgBase,
      body: BlocBuilder<SessionBloc, SessionState>(
        builder: (context, st) {
          if (st is! ResumePrompt) return const SizedBox.shrink();
          final s = st.session;
          return PageFrame(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: Tokens.s32),
                        const LogoMark(size: 72),
                        const SizedBox(height: Tokens.s12),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Spinfolk', style: Tokens.numeral(36)),
                        ),
                        const SizedBox(height: Tokens.s32),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Tokens.bgSurface,
                            border: Border.all(color: Tokens.line),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SESSION IN PROGRESS',
                                style: Tokens.caption.copyWith(
                                  color: Tokens.taker,
                                ),
                              ),
                              const SizedBox(height: Tokens.s8),
                              Text(
                                'Round ${s.round} · ${s.playerCount} players',
                                style: Tokens.title2,
                              ),
                              const SizedBox(height: Tokens.s8),
                              Text(
                                status(s),
                                style: const TextStyle(
                                  color: Tokens.textSecondary,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (st.failure != null) ...[
                          const SizedBox(height: Tokens.s12),
                          NoticeBanner(st.failure!.message),
                        ],
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height:
                      (Tokens.barPrimary +
                          Tokens.barGap +
                          Tokens.barSecondary) *
                      sc,
                  child: NativeActionBar(
                    items: const [
                      ActionBarItem(
                        id: 'resume',
                        label: 'Resume Session',
                        style: ActionBarStyle.primary,
                      ),
                      ActionBarItem(
                        id: 'end',
                        label: 'End Session',
                        style: ActionBarStyle.destructive,
                      ),
                    ],
                    onTap: (id) => switch (id) {
                      'resume' => bloc.add(const ResumeConfirmed()),
                      'end' => nav.confirmEnd(),
                      _ => null,
                    },
                  ),
                ),
                const SizedBox(height: Tokens.s8),
                Text(
                  'Ending clears players and rounds. Voice settings stay.',
                  style: Tokens.footnote,
                  textAlign: TextAlign.center,
                  textScaler: besideIsland(context),
                ),
                const SizedBox(height: Tokens.s8),
              ],
            ),
          );
        },
      ),
    );
  }
}
