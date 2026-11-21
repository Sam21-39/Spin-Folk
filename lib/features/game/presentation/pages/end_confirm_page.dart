import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_navigator.dart';
import '../../../../app/tokens.dart';
import '../../../../app/ui.dart';
import '../../../../platform/native_action_bar.dart';
import '../../../../core/failure.dart';
import '../../../session/domain/entities/session.dart';
import '../../../session/presentation/bloc/session_bloc.dart';

class EndConfirmPage extends StatelessWidget {
  const EndConfirmPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<SessionBloc>();
    final nav = context.read<AppNavigator>();
    final sc = barScale(context);
    return BlocBuilder<SessionBloc, SessionState>(
      builder: (context, st) {
        final (Session, Failure?)? cur = switch (st) {
          SessionActive() => (st.session, st.failure),
          ResumePrompt() => (st.session, st.failure),
          _ => null,
        };
        if (cur == null) return const SizedBox.shrink();
        final (session, failure) = cur;
        final n = session.playerCount;
        final r = session.round;
        return Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Tokens.s8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: Tokens.maxContentWidth,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            Semantics(
                              namesRoute: true,
                              explicitChildNodes: true,
                              child: Material(
                                color: Tokens.bgRaised,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  side: const BorderSide(color: Tokens.line),
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                    horizontal: 20,
                                  ),
                                  child: Column(
                                    children: [
                                      const Text(
                                        'End this session?',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Tokens.textPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: Tokens.s4),
                                      Text(
                                        'Clears $n players and $r '
                                        '${r == 1 ? 'round' : 'rounds'}. '
                                        'Voice settings stay. '
                                        'Lock Screen activity ends too.',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Tokens.textSecondary,
                                          fontSize: 13,
                                          height: 18 / 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (failure != null)
                              Padding(
                                padding: const EdgeInsets.only(top: Tokens.s8),
                                child: NoticeBanner(failure.message),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Tokens.s8),
                    SizedBox(
                      height:
                          (Tokens.barSecondary +
                              Tokens.barGap +
                              Tokens.barSecondary) *
                          sc,
                      child: NativeActionBar(
                        items: const [
                          ActionBarItem(
                            id: 'end',
                            label: 'End Session',
                            style: ActionBarStyle.destructive,
                          ),
                          ActionBarItem(id: 'cancel', label: 'Cancel'),
                        ],
                        onTap: (id) => switch (id) {
                          'end' => bloc.add(const EndConfirmed()),
                          'cancel' => nav.game(),
                          _ => null,
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
