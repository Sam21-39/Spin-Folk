import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_navigator.dart';
import '../../../../app/logo_mark.dart';
import '../../../../app/tokens.dart';
import '../../../../app/ui.dart';
import '../../../../platform/native_action_bar.dart';
import '../../../session/domain/entities/game_record.dart';
import '../../domain/rules/history_labels.dart';
import '../cubit/history_cubit.dart';
import '../widgets/game_row.dart';
import '../widgets/undo_toast.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Tokens.bgBase,
    body: TopRoute(
      path: '/history',
      builder: (context, covered) => BlocBuilder<HistoryCubit, HistoryState>(
        builder: (context, h) => PageFrame(
          inset: false,
          child: !h.loaded
              ? const SizedBox.shrink()
              : (h.games.isEmpty && h.pending.isEmpty
                    ? _Empty(covered: covered)
                    : _List(h, covered: covered)),
        ),
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.covered});
  final bool covered;

  @override
  Widget build(BuildContext context) {
    final nav = context.read<AppNavigator>();
    final sc = barScale(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Tokens.margin),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextLink('Home', leading: true, onTap: nav.home),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.margin),
            child: Column(
              children: [
                const SizedBox(height: Tokens.s32),
                const LogoMark(size: 72),
                const SizedBox(height: Tokens.s16),
                const Text(
                  'No past games yet',
                  style: Tokens.title2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Tokens.s8),
                const Text(
                  'Finished games show up here with their round log. '
                  'They stay on this iPhone only.',
                  style: Tokens.subhead,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Tokens.margin,
            0,
            Tokens.margin,
            Tokens.s8,
          ),
          child: SizedBox(
            height: Tokens.barSecondary * sc,
            child: covered
                ? null
                : NativeActionBar(
                    items: const [
                      ActionBarItem(id: 'start', label: 'Start a game'),
                    ],
                    onTap: (_) => nav.setup(),
                  ),
          ),
        ),
      ],
    );
  }
}

class _List extends StatelessWidget {
  const _List(this.h, {required this.covered});
  final HistoryState h;
  final bool covered;

  @override
  Widget build(BuildContext context) {
    final nav = context.read<AppNavigator>();
    final cubit = context.read<HistoryCubit>();
    final now = DateTime.now();
    final h24 = MediaQuery.alwaysUse24HourFormatOf(context);
    final reduce = MediaQuery.disableAnimationsOf(context);

    // Buckets in list order (already newest first).
    final groups = <(String, List<GameRecord>)>[];
    for (final g in h.games) {
      final label = groupLabel(
        DateTime.fromMillisecondsSinceEpoch(g.endedAtMs),
        now,
      );
      if (groups.isEmpty || groups.last.$1 != label) {
        groups.add((label, []));
      }
      groups.last.$2.add(g);
    }

    Widget row(GameRecord g, bool first) => Dismissible(
      key: ValueKey(g.id),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.6},
      resizeDuration: Tokens.rowCollapse,
      background: Container(
        color: Tokens.giver,
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: 96,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete_outline, color: Tokens.bgBase),
              Text(
                'Delete',
                style: TextStyle(
                  color: Tokens.bgBase,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
      onUpdate: (d) {
        if (d.reached && !d.previousReached) HapticFeedback.heavyImpact();
      },
      onDismissed: (_) => cubit.delete([g.id]),
      child: Semantics(
        customSemanticsActions: {
          const CustomSemanticsAction(label: 'Delete game'): () =>
              cubit.delete([g.id]),
        },
        child: GameRow(
          game: g,
          now: now,
          h24: h24,
          divider: !first,
          onTap: () => nav.historyDetail(g.id),
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Tokens.margin,
            0,
            Tokens.margin,
            84,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextLink('Home', leading: true, onTap: nav.home),
                    ),
                  ),
                  if (h.games.isNotEmpty)
                    Flexible(
                      child: TextLink(
                        'Clear all',
                        color: Tokens.giver,
                        onTap: nav.confirmClear,
                      ),
                    ),
                ],
              ),
              Semantics(
                header: true,
                child: const Text('History', style: Tokens.largeTitle),
              ),
              if (h.failure != null) ...[
                const SizedBox(height: Tokens.s12),
                NoticeBanner(h.failure!.message),
              ],
              for (final (label, games) in groups) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                  child: Text(
                    label,
                    style: Tokens.footnote.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
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
                      for (final (i, g) in games.indexed) row(g, i == 0),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: Tokens.s16),
              const Text(
                'Stored only on this iPhone. Swipe left on a game to delete it.',
                style: Tokens.footnote,
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 8,
          child: AnimatedSwitcher(
            duration: reduce
                ? Duration.zero
                : const Duration(milliseconds: 200),
            child: h.pending.isEmpty
                ? const SizedBox.shrink()
                : UndoToast(
                    // New key restarts the countdown ring.
                    key: ValueKey('${h.pending.first.id}-${h.pending.length}'),
                    count: h.pending.length,
                    flat: covered,
                    onUndo: cubit.undo,
                  ),
          ),
        ),
      ],
    );
  }
}
