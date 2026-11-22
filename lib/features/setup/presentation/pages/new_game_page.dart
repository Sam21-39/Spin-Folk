import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_navigator.dart';
import '../../../../app/tokens.dart';
import '../../../../app/ui.dart';
import '../../../../platform/native_action_bar.dart';
import '../../../../platform/native_picker.dart';
import '../../../game/presentation/widgets/dial_preview.dart';
import '../../../session/presentation/bloc/session_bloc.dart';
import '../cubit/setup_cubit.dart';

class NewGamePage extends StatelessWidget {
  const NewGamePage({required this.editing, super.key});
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final nav = context.read<AppNavigator>();
    final cubit = context.read<SetupCubit>();
    final s = barScale(context);
    return Scaffold(
      backgroundColor: Tokens.bgBase,
      body: TopRoute(
        path: '/new',
        builder: (context, covered) => PageFrame(
          inset: false,
          child: Column(
            children: [
              Expanded(
                // Full-width scroll view: edge swipes scroll past the native wheel.
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Tokens.margin,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (editing)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: nav.game,
                            child: const Text('Cancel'),
                          ),
                        )
                      else
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextLink(
                            'Home',
                            leading: true,
                            onTap: nav.home,
                          ),
                        ),
                      const SizedBox(height: Tokens.s8),
                      Text(
                        editing ? 'Edit Players' : 'New game',
                        style: Tokens.largeTitle,
                      ),
                      const SizedBox(height: Tokens.s4),
                      const Text(
                        'How many in the circle?',
                        style: TextStyle(
                          color: Tokens.textSecondary,
                          fontSize: 17,
                        ),
                      ),
                      if (!editing)
                        BlocBuilder<SessionBloc, SessionState>(
                          buildWhen: (a, b) => _notice(a) != _notice(b),
                          builder: (context, st) {
                            final notice = _notice(st);
                            return notice == null
                                ? const SizedBox.shrink()
                                : Padding(
                                    padding: const EdgeInsets.only(
                                      top: Tokens.s12,
                                    ),
                                    child: NoticeBanner(notice),
                                  );
                          },
                        ),
                      const SizedBox(height: Tokens.s12),
                      SizedBox(
                        height: Tokens.chip * s,
                        child: covered
                            ? null
                            : BlocBuilder<SetupCubit, SetupState>(
                                buildWhen: (a, b) => a.count != b.count,
                                builder: (context, st) => NativeActionBar(
                                  layout: ActionBarLayout.row,
                                  items: [
                                    for (final n in const [4, 6, 8, 10, 12])
                                      ActionBarItem(
                                        id: 'count:$n',
                                        label: '$n',
                                        style: st.count == n
                                            ? ActionBarStyle.chipOn
                                            : ActionBarStyle.chip,
                                      ),
                                  ],
                                  onTap: (id) {
                                    HapticFeedback.selectionClick();
                                    cubit.countChanged(
                                      int.parse(id.substring(6)),
                                    );
                                  },
                                ),
                              ),
                      ),
                      const SizedBox(height: Tokens.s12),
                      SizedBox(
                        height: Tokens.pickerHeight,
                        child: LayoutBuilder(
                          builder: (context, c) => Row(
                            children: [
                              Expanded(
                                child: covered
                                    ? const SizedBox.shrink()
                                    : BlocBuilder<SetupCubit, SetupState>(
                                        buildWhen: (a, b) => a.count != b.count,
                                        builder: (context, st) => NativePicker(
                                          min: SetupCubit.minPlayers,
                                          max: SetupCubit.maxPlayers,
                                          value: st.count,
                                          onChanged: cubit.countChanged,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: Tokens.s12),
                              SizedBox(
                                width: min(170, (c.maxWidth - Tokens.s12) / 2),
                                child: _Preview(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: Tokens.s12),
                      const Text(
                        'Sit in number order, clockwise. Player 1 sits where '
                        'the bottle’s neck points now.',
                        style: TextStyle(
                          color: Tokens.textSecondary,
                          fontSize: 15,
                          height: 21 / 15,
                        ),
                      ),
                      const SizedBox(height: Tokens.s12),
                      BlocBuilder<SetupCubit, SetupState>(
                        buildWhen: (a, b) => a.namedCount != b.namedCount,
                        builder: (context, st) => _NamesRow(
                          named: st.namedCount,
                          onTap: () {
                            cubit.namesOpened();
                            nav.names(editing: editing);
                          },
                        ),
                      ),
                      const SizedBox(height: Tokens.s12),
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
                  height: Tokens.barProminent * s,
                  child: covered
                      ? null
                      : NativeActionBar(
                          items: [
                            ActionBarItem(
                              id: editing ? 'save' : 'start',
                              label: editing ? 'Save Players' : 'Start session',
                              style: ActionBarStyle.prominent,
                            ),
                          ],
                          onTap: (id) {
                            final st = cubit.state;
                            if (editing && id == 'save') {
                              context.read<SessionBloc>().add(
                                PlayersEdited(st.count, st.namesForCount),
                              );
                              nav.game();
                            } else if (!editing && id == 'start') {
                              context.read<SessionBloc>().add(
                                SessionStarted(st.count, st.namesForCount),
                              );
                            }
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _notice(SessionState st) => switch (st) {
  NoSession() => st.notice,
  ResumePrompt() => st.failure?.message,
  _ => null,
};

class _Preview extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Tokens.bgSurface,
      border: Border.all(color: Tokens.line),
      borderRadius: BorderRadius.circular(24),
    ),
    child: BlocBuilder<SetupCubit, SetupState>(
      buildWhen: (a, b) => a.count != b.count,
      builder: (context, st) => Semantics(
        image: true,
        label: 'Seating preview for ${st.count} players',
        child: Column(
          children: [
            Expanded(child: DialPreview(n: st.count)),
            const SizedBox(height: Tokens.s4),
            Text(
              'Live seat preview',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Tokens.footnote,
              textScaler: besideIsland(context),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NamesRow extends StatelessWidget {
  const _NamesRow({required this.named, required this.onTap});
  final int named;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: Tokens.touch),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Tokens.bgSurface,
          border: Border.all(color: Tokens.line),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    named > 0 ? 'Edit names' : 'Add names',
                    style: Tokens.headline,
                  ),
                  Text(
                    named > 0 ? '$named named' : 'Optional · numbers work fine',
                    style: Tokens.footnote,
                  ),
                ],
              ),
            ),
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
  );
}
