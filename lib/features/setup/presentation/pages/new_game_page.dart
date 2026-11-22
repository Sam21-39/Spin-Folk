import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_navigator.dart';
import '../../../../app/logo_mark.dart';
import '../../../../app/tokens.dart';
import '../../../../app/ui.dart';
import '../../../../platform/native_action_bar.dart';
import '../../../../platform/native_picker.dart';
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
      body: PageFrame(
        inset: false,
        child: Column(
          children: [
            Expanded(
              // Full-width scroll view: edge swipes scroll past the native wheel.
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: Tokens.margin),
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
                      Padding(
                        padding: const EdgeInsets.only(top: Tokens.s12),
                        child: Row(
                          children: [
                            const LogoMark(),
                            const SizedBox(width: Tokens.s12),
                            Flexible(
                              child: Text(
                                'Spinfolk',
                                style: Tokens.numeral(30),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: Tokens.s16),
                    Text(
                      editing ? 'Edit Players' : 'New Game',
                      style: Tokens.largeTitle,
                    ),
                    const SizedBox(height: Tokens.s4),
                    const Text(
                      'How many players?',
                      style: TextStyle(
                        color: Tokens.textSecondary,
                        fontSize: 17,
                      ),
                    ),
                    if (!editing)
                      BlocBuilder<SessionBloc, SessionState>(
                        buildWhen: (a, b) =>
                            (a is NoSession ? a.notice : null) !=
                            (b is NoSession ? b.notice : null),
                        builder: (context, st) {
                          final notice = st is NoSession ? st.notice : null;
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
                    const SizedBox(height: Tokens.s8),
                    SizedBox(
                      height: Tokens.pickerHeight,
                      child: BlocBuilder<SetupCubit, SetupState>(
                        buildWhen: (a, b) => a.count != b.count,
                        builder: (context, st) => NativePicker(
                          min: SetupCubit.minPlayers,
                          max: SetupCubit.maxPlayers,
                          value: st.count,
                          onChanged: cubit.countChanged,
                        ),
                      ),
                    ),
                    const SizedBox(height: Tokens.s12),
                    Container(
                      padding: const EdgeInsets.all(Tokens.s16),
                      decoration: BoxDecoration(
                        color: Tokens.bgSurface,
                        border: Border.all(color: Tokens.line),
                        borderRadius: BorderRadius.circular(Tokens.r20),
                      ),
                      child: Row(
                        children: [
                          const LogoMark(size: 64, rotation: 0),
                          const SizedBox(width: Tokens.s16),
                          const Expanded(
                            child: Text(
                              'Sit in a circle in number order, going clockwise. '
                              'Player 1 sits at the top of the dial.',
                              style: TextStyle(
                                color: Tokens.textSecondary,
                                fontSize: 15,
                                height: 21 / 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    BlocBuilder<SetupCubit, SetupState>(
                      buildWhen: (a, b) => a.namedCount != b.namedCount,
                      builder: (context, st) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          cubit.namesOpened();
                          nav.names(editing: editing);
                        },
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: Tokens.touch,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Semantics(
                              button: true,
                              child: Text.rich(
                                st.namedCount > 0
                                    ? TextSpan(
                                        text:
                                            'Edit Names · ${st.namedCount} named',
                                        style: const TextStyle(
                                          color: Tokens.taker,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    : const TextSpan(
                                        children: [
                                          TextSpan(
                                            text: 'Add Names',
                                            style: TextStyle(
                                              color: Tokens.taker,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          TextSpan(
                                            text: ' (optional)',
                                            style: TextStyle(
                                              color: Tokens.textTertiary,
                                            ),
                                          ),
                                        ],
                                        style: TextStyle(fontSize: 17),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.margin),
              child: Column(
                children: [
                  SizedBox(
                    height: Tokens.barPrimary * s,
                    child: NativeActionBar(
                      items: [
                        ActionBarItem(
                          id: editing ? 'save' : 'start',
                          label: editing ? 'Save Players' : 'Start Session',
                          style: ActionBarStyle.primary,
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
                  const SizedBox(height: Tokens.s8),
                  Text(
                    'Players stay numbered unless you add names.',
                    style: Tokens.footnote,
                    textAlign: TextAlign.center,
                    textScaler: besideIsland(context),
                  ),
                  const SizedBox(height: Tokens.s8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
