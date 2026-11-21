import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_navigator.dart';
import '../../../../app/tokens.dart';
import '../../../../app/ui.dart';
import '../../../../platform/adaptive_controls.dart';
import '../../../../platform/announcer.dart';
import '../../../session/domain/entities/session.dart';
import '../../../session/presentation/bloc/session_bloc.dart';
import '../../../setup/presentation/cubit/setup_cubit.dart';
import '../../domain/prefs.dart';
import '../cubit/settings_cubit.dart';

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
                    const _VoiceSection(),
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
                    BlocBuilder<SettingsCubit, SettingsState>(
                      buildWhen: (a, b) => a.lockScreenNote != b.lockScreenNote,
                      builder: (context, s) => s.lockScreenNote == null
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                              child: Text(
                                s.lockScreenNote!,
                                style: Tokens.footnote,
                              ),
                            ),
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
    this.trailingWidget,
    this.color = Tokens.textPrimary,
    this.enabled = true,
    this.onTap,
  });
  final String text;
  final String? trailing;
  final Widget? trailingWidget;
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
            ?trailingWidget,
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

class _VoiceSection extends StatelessWidget {
  const _VoiceSection();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SettingsCubit>();
    // Ancestor for the Material fallback off iOS; nothing is drawn over the
    // iOS 26 platform views.
    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BlocBuilder<Announcer, bool>(
            builder: (context, unavailable) => unavailable
                ? const Padding(
                    padding: EdgeInsets.only(bottom: Tokens.s12),
                    child: NoticeBanner(Announcer.unavailableText),
                  )
                : const SizedBox.shrink(),
          ),
          BlocBuilder<SettingsCubit, SettingsState>(
            builder: (context, state) {
              final prefs = state.prefs;
              final failure = state.failure;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (failure != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Tokens.s12),
                      child: NoticeBanner(failure.message),
                    ),
                  const _Label('VOICE'),
                  _Card(
                    children: [
                      MergeSemantics(
                        child: _Row(
                          text: 'Announcements',
                          trailingWidget: NativeSwitch(
                            value: prefs.announce,
                            onChanged: cubit.announceToggled,
                            activeColor: Tokens.taker,
                          ),
                        ),
                      ),
                      const _Divider(),
                      _Row(
                        text: 'Voice',
                        trailingWidget: Flexible(
                          child: Text(
                            '${state.voiceLabel} ›',
                            style: Tokens.subhead,
                            textAlign: TextAlign.end,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        onTap: cubit.voiceRowTapped,
                      ),
                      if (state.voiceListOpen) ...[
                        _Choice(
                          label: 'Default',
                          selected: prefs.voiceId == null,
                          onTap: () => cubit.voiceSelected(null),
                        ),
                        for (final v in state.voices)
                          _Choice(
                            label: v.label,
                            selected: v.id == prefs.voiceId,
                            onTap: () => cubit.voiceSelected(v.id),
                          ),
                      ],
                      const _Divider(),
                      Semantics(
                        label: 'Speech speed',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text('Speed', style: Tokens.body),
                                  ),
                                  Text(
                                    rateLabel(prefs.rate),
                                    style: Tokens.subhead,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 44,
                                width: double.infinity,
                                child: NativeSlider(
                                  value: prefs.rate,
                                  min: Prefs.minRate,
                                  max: Prefs.maxRate,
                                  onChanged: cubit.rateChanged,
                                  onChangeEnd: (_) => cubit.rateCommitted(),
                                  activeColor: Tokens.taker,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const _Divider(),
                      _Row(
                        text: 'Preview',
                        trailingWidget: Flexible(
                          child: Semantics(
                            button: true,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: context.read<Announcer>().preview,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minHeight: 44),
                                child: Center(
                                  child: Text(
                                    'Play sample',
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                      color: Tokens.taker,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: Text(
                      'Only voices already on this iPhone are listed. '
                      'Nothing downloads.',
                      style: Tokens.footnote,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 6, 16, 6),
          child: Row(
            children: [
              Expanded(child: Text(label, style: Tokens.subhead)),
              if (selected)
                const Text(
                  '✓',
                  style: TextStyle(color: Tokens.taker, fontSize: 17),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
