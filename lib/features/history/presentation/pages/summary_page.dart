import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_navigator.dart';
import '../../../../app/logo_mark.dart';
import '../../../../app/tokens.dart';
import '../../../../app/ui.dart';
import '../../../../platform/native_action_bar.dart';
import '../../../session/domain/entities/game_record.dart';
import '../../../session/domain/entities/session.dart';
import '../../../session/domain/rules/labels.dart';
import '../../../session/presentation/bloc/session_bloc.dart';
import '../../domain/rules/history_labels.dart';
import '../widgets/stat_tiles.dart';

class SummaryPage extends StatelessWidget {
  const SummaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.read<AppNavigator>();
    final bloc = context.read<SessionBloc>();
    final sc = barScale(context);
    return Scaffold(
      backgroundColor: Tokens.bgBase,
      body: BlocBuilder<SessionBloc, SessionState>(
        builder: (context, st) {
          if (st is! SessionSummary) return const SizedBox.shrink();
          final g = st.game;
          final stats = GameStats.of(g.rounds);
          return TopRoute(
            path: '/summary',
            builder: (context, covered) => PageFrame(
              inset: false,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Tokens.margin,
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: Tokens.s24),
                          const LogoMark(size: 72),
                          const SizedBox(height: Tokens.s12),
                          Semantics(
                            header: true,
                            child: const Text(
                              'Good game.',
                              style: Tokens.largeTitle,
                            ),
                          ),
                          Text(
                            '${durationLabel(g.durationMs)} · '
                            '${roundsLabel(g.rounds.length)} · '
                            '${g.playerCount} players',
                            style: Tokens.subhead,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: Tokens.s16),
                          StatTiles(stats),
                          const SizedBox(height: Tokens.s16),
                          _Ratio(stats),
                          const SizedBox(height: Tokens.s16),
                          _Leaders(g.players, stats),
                          const SizedBox(height: Tokens.s16),
                          const Text(
                            'Saved to History on this iPhone.',
                            style: Tokens.footnote,
                          ),
                          TextLink(
                            'View round log',
                            onTap: () => nav.historyDetail(g.id),
                          ),
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
                    child: SizedBox(
                      height:
                          (Tokens.barProminent +
                              Tokens.barGap +
                              Tokens.barSecondary) *
                          sc,
                      child: covered
                          ? null
                          : NativeActionBar(
                              items: const [
                                ActionBarItem(
                                  id: 'again',
                                  label: 'Play again · same players',
                                  style: ActionBarStyle.prominent,
                                ),
                                ActionBarItem(id: 'done', label: 'Done'),
                              ],
                              onTap: (id) => switch (id) {
                                'again' => bloc.add(
                                  SessionStarted(g.playerCount, [
                                    for (final p in g.players) p.name,
                                  ]),
                                ),
                                'done' => bloc.add(const SummaryDismissed()),
                                _ => null,
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Ratio extends StatelessWidget {
  const _Ratio(this.s);
  final GameStats s;

  @override
  Widget build(BuildContext context) {
    final parts = [
      (s.truths, const Color(0xFFE8EEF7)),
      (s.dares, const Color(0xFF7C8BA5)),
      (s.passes, Tokens.line),
    ];
    return Semantics(
      image: true,
      label:
          '${s.truths} ${s.truths == 1 ? 'truth' : 'truths'}, '
          '${s.dares} ${s.dares == 1 ? 'dare' : 'dares'}, '
          '${s.passes} ${s.passes == 1 ? 'pass' : 'passes'}',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                for (final (n, c) in parts)
                  if (n > 0)
                    Expanded(
                      flex: n,
                      child: ColoredBox(color: c),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Leaders extends StatelessWidget {
  const _Leaders(this.players, this.s);
  final List<Player> players;
  final GameStats s;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, ({int seat, int count}) v, Color c) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Tokens.subhead)),
          const SizedBox(width: Tokens.s8),
          Flexible(
            child: Text(
              '${displayLabel(playerAt(players, v.seat))} · ${v.count}×',
              style: TextStyle(
                color: c,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
    final t = s.topTaker, g = s.topGiver;
    if (t == null && g == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Tokens.bgSurface,
        border: Border.all(color: Tokens.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          if (t != null) row('Taker most often', t, Tokens.taker),
          if (g != null) row('Asked most', g, Tokens.giver),
        ],
      ),
    );
  }
}
