import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_navigator.dart';
import '../../../../app/logo_mark.dart';
import '../../../../app/tokens.dart';
import '../../../../app/ui.dart';
import '../../../../platform/glass_button.dart';
import '../../../../platform/native_action_bar.dart';
import '../../../game/presentation/widgets/dial_preview.dart';
import '../../../history/domain/rules/history_labels.dart';
import '../../../history/presentation/cubit/history_cubit.dart';
import '../../../history/presentation/widgets/game_row.dart';
import '../../../session/domain/entities/session.dart';
import '../../../session/domain/rules/labels.dart';
import '../../../session/domain/rules/selection.dart';
import '../../../session/presentation/bloc/session_bloc.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Tokens.bgBase,
    body: BlocBuilder<SessionBloc, SessionState>(
      builder: (context, st) {
        if (st is! NoSession && st is! ResumePrompt) {
          return const SizedBox.shrink();
        }
        return TopRoute(
          path: '/',
          builder: (context, covered) =>
              PageFrame(inset: false, child: _Home(st, covered: covered)),
        );
      },
    ),
  );
}

class _Home extends StatelessWidget {
  const _Home(this.st, {required this.covered});
  final SessionState st;
  final bool covered;

  @override
  Widget build(BuildContext context) {
    final nav = context.read<AppNavigator>();
    final bloc = context.read<SessionBloc>();
    final sc = barScale(context);
    final now = DateTime.now();
    final h24 = MediaQuery.alwaysUse24HourFormatOf(context);
    final resume = st is ResumePrompt ? st as ResumePrompt : null;
    final notice = switch (st) {
      NoSession() => (st as NoSession).notice,
      ResumePrompt() => (st as ResumePrompt).failure?.message,
      _ => null,
    };
    Widget hubBar(List<ActionBarItem> items, void Function(String) onTap) =>
        SizedBox(
          height: Tokens.barHub * sc,
          child: covered ? null : NativeActionBar(items: items, onTap: onTap),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: Tokens.margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: Tokens.s8),
          Row(
            children: [
              const LogoMark(),
              const SizedBox(width: Tokens.s12),
              Expanded(
                child: Text(
                  'Spinfolk',
                  style: Tokens.numeral(26),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GlassButton(
                label: 'History',
                symbol: 'clock.arrow.circlepath',
                flat: covered,
                onPressed: nav.history,
                child: const Icon(
                  Icons.history,
                  color: Tokens.textPrimary,
                  size: 22,
                ),
              ),
            ],
          ),
          if (notice != null) ...[
            const SizedBox(height: Tokens.s12),
            NoticeBanner(notice),
          ],
          const SizedBox(height: Tokens.s16),
          if (resume != null) ...[
            _ResumeCard(resume.session, now: now),
            const SizedBox(height: Tokens.s12),
            hubBar(const [
              ActionBarItem(
                id: 'resume',
                label: 'Resume game',
                style: ActionBarStyle.prominent,
              ),
            ], (_) => bloc.add(const ResumeConfirmed())),
            const SizedBox(height: Tokens.s12),
          ],
          hubBar([
            ActionBarItem(
              id: 'new',
              label: 'New game',
              style: resume != null
                  ? ActionBarStyle.secondary
                  : ActionBarStyle.prominent,
            ),
          ], (_) => nav.setup()),
          if (resume != null) ...[
            const SizedBox(height: Tokens.s8),
            const Text(
              'Starting a new game ends and saves the current one.',
              style: Tokens.footnote,
            ),
          ],
          BlocBuilder<HistoryCubit, HistoryState>(
            builder: (context, h) {
              if (h.games.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: Tokens.s24),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Recent', style: Tokens.title2),
                      ),
                      TextLink('See all', onTap: nav.history),
                    ],
                  ),
                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Tokens.bgSurface,
                      border: Border.all(color: Tokens.line),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      children: [
                        for (final (i, g) in h.games.take(3).indexed)
                          GameRow(
                            game: g,
                            now: now,
                            h24: h24,
                            divider: i > 0,
                            onTap: () => nav.historyDetail(g.id),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Tokens.s16),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard(this.s, {required this.now});
  final Session s;
  final DateTime now;

  String _sub() {
    final n = '${s.playerCount} players';
    if (s.log.isEmpty) return '$n · no rounds yet';
    final e = s.log.last;
    if (e.result == RoundResult.pass) return '$n · last: passed';
    final giver = shortLabel(playerAt(s.players, e.giver));
    final taker = shortLabel(playerAt(s.players, e.taker));
    return '$n · last: $giver → $taker · ${resultLabel(e.result)}';
  }

  @override
  Widget build(BuildContext context) {
    final o = s.outcome;
    final since = now.millisecondsSinceEpoch - s.startedAtMs;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Tokens.bgSurface,
        border: Border.all(color: Tokens.line),
        borderRadius: BorderRadius.circular(Tokens.r28),
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 64,
            child: DialPreview(
              n: s.playerCount,
              orientation: o == null ? 0 : seatAngle(o.taker, s.playerCount),
            ),
          ),
          const SizedBox(width: Tokens.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IN PROGRESS · ${durationLabel(since < 0 ? 0 : since).toUpperCase()}',
                  style: Tokens.caption.copyWith(color: Tokens.taker),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text('Round ${s.round}', style: Tokens.title2),
                Text(
                  _sub(),
                  style: Tokens.subhead,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
