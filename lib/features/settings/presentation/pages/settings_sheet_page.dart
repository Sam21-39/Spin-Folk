import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_navigator.dart';
import '../../../../app/tokens.dart';
import '../../../../app/ui.dart';
import '../../../session/domain/entities/session.dart';
import '../../../session/presentation/bloc/session_bloc.dart';
import '../../../setup/presentation/cubit/setup_cubit.dart';

class SettingsSheetPage extends StatelessWidget {
  const SettingsSheetPage({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.read<AppNavigator>();
    final setup = context.read<SetupCubit>();
    return BlocBuilder<SessionBloc, SessionState>(
      builder: (context, st) {
        if (st is! SessionActive) return const SizedBox.shrink();
        final session = st.session;
        final named = session.players.where((p) => p.name != null).length;
        final canEdit = session.phase == Phase.ready && !st.spinning;
        return SheetFrame(
          title: 'Session',
          onDone: nav.game,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('PLAYERS'),
                    _Card(
                      children: [
                        _Row(
                          text: named == 0
                              ? '${session.playerCount} players'
                              : '${session.playerCount} players · $named named',
                        ),
                        const _Divider(),
                        _Row(
                          text: 'Edit Players',
                          trailing: '›',
                          enabled: canEdit,
                          onTap: () {
                            setup.seed(session.playerCount, [
                              for (final p in session.players) p.name,
                            ]);
                            nav.setup(editing: true);
                          },
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 6, 16, 0),
                      child: Text(
                        'Editing between rounds keeps the session; '
                        'current round resets.',
                        style: Tokens.footnote,
                      ),
                    ),
                    const _Label('SESSION'),
                    _Card(
                      children: [
                        _Row(
                          text: 'End Session',
                          color: Tokens.giver,
                          enabled: !st.spinning,
                          onTap: nav.confirmEnd,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
    child: Text(
      text,
      style: const TextStyle(
        color: Tokens.textTertiary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Tokens.bgSurface,
      border: Border.all(color: Tokens.line),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(children: children),
  );
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Tokens.line,
    child: SizedBox(height: 1, width: double.infinity),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.text,
    this.trailing,
    this.color = Tokens.textPrimary,
    this.enabled = true,
    this.onTap,
  });
  final String text;
  final String? trailing;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final interactive = onTap != null;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 50),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: Tokens.body.copyWith(
                  color: enabled ? color : Tokens.textTertiary,
                ),
              ),
            ),
            if (trailing != null)
              ExcludeSemantics(
                child: Text(
                  trailing!,
                  style: Tokens.body.copyWith(color: Tokens.textTertiary),
                ),
              ),
          ],
        ),
      ),
    );
    if (!interactive) return row;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: row,
      ),
    );
  }
}
