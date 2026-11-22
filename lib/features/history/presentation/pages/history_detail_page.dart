import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_navigator.dart';
import '../../../../app/tokens.dart';
import '../../../../app/ui.dart';
import '../../../../platform/native_action_bar.dart';
import '../../../session/domain/entities/game_record.dart';
import '../../../session/domain/rules/labels.dart';
import '../../../session/presentation/bloc/session_bloc.dart';
import '../../domain/rules/history_labels.dart';
import '../cubit/history_cubit.dart';
import '../widgets/round_log_list.dart';
import '../widgets/stat_tiles.dart';

class HistoryDetailPage extends StatelessWidget {
  const HistoryDetailPage({required this.id, super.key});
  final String id;

  @override
  Widget build(BuildContext context) {
    final nav = context.read<AppNavigator>();
    final bloc = context.read<SessionBloc>();
    final sc = barScale(context);
    return Scaffold(
      backgroundColor: Tokens.bgBase,
      body: TopRoute(
        path: '/history/$id',
        builder: (context, covered) => BlocBuilder<HistoryCubit, HistoryState>(
          builder: (context, h) {
            if (!h.loaded) return const SizedBox.shrink();
            final g = h.games.where((g) => g.id == id).firstOrNull;
            if (g == null) {
              return PageFrame(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextLink('History', leading: true, onTap: nav.history),
                    const SizedBox(height: Tokens.s16),
                    const Text(
                      'This game is no longer in History.',
                      style: Tokens.subhead,
                    ),
                  ],
                ),
              );
            }
            final ended = DateTime.fromMillisecondsSinceEpoch(g.endedAtMs);
            final now = DateTime.now();
            final h24 = MediaQuery.alwaysUse24HourFormatOf(context);
            return PageFrame(
              inset: false,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Tokens.margin,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextLink(
                            'History',
                            leading: true,
                            onTap: nav.history,
                          ),
                          Semantics(
                            header: true,
                            child: Text(
                              dayLabel(ended, now),
                              style: Tokens.largeTitle,
                            ),
                          ),
                          Text(
                            '${timeLabel(ended, h24: h24)} · '
                            '${g.playerCount} players · '
                            '${roundsLabel(g.rounds.length)} · '
                            '${durationLabel(g.durationMs)}',
                            style: Tokens.subhead,
                          ),
                          const SizedBox(height: Tokens.s16),
                          StatTiles(GameStats.of(g.rounds)),
                          const SizedBox(height: Tokens.s16),
                          Wrap(
                            spacing: Tokens.s8,
                            runSpacing: Tokens.s8,
                            children: [
                              for (final p in g.players)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: const ShapeDecoration(
                                    color: Tokens.bgRaised,
                                    shape: StadiumBorder(),
                                  ),
                                  child: Text(
                                    shortLabel(p),
                                    style: const TextStyle(
                                      color: Tokens.textPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                            child: Text(
                              'ROUND LOG',
                              style: Tokens.footnote.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          RoundLogList(players: g.players, rounds: g.rounds),
                          const SizedBox(height: Tokens.s16),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Tokens.margin,
                      Tokens.s8,
                      Tokens.margin,
                      Tokens.s8,
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: Tokens.barProminent * sc,
                          child: covered
                              ? null
                              : NativeActionBar(
                                  items: const [
                                    ActionBarItem(
                                      id: 'again',
                                      label: 'Play again with this circle',
                                      style: ActionBarStyle.prominent,
                                    ),
                                  ],
                                  onTap: (_) => bloc.add(
                                    SessionStarted(g.playerCount, [
                                      for (final p in g.players) p.name,
                                    ]),
                                  ),
                                ),
                        ),
                        if (context.watch<SessionBloc>().state is ResumePrompt)
                          const Padding(
                            padding: EdgeInsets.only(top: Tokens.s8),
                            child: Text(
                              'Starting a new game ends and saves the current one.',
                              style: Tokens.footnote,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        TextLink(
                          'Delete game',
                          color: Tokens.giver,
                          onTap: () => nav.confirmDelete(id),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
