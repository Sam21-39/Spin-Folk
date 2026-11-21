// TEMP(phase-1): glass proof harness. Delete in Phase 2.
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../app/tokens.dart';
import '../features/setup/presentation/cubit/setup_cubit.dart';
import '../platform/native_action_bar.dart';
import '../platform/native_picker.dart';
import 'proof_cubit.dart';
import 'proof_spin.dart';

class GlassProofPage extends StatelessWidget {
  const GlassProofPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ProofCubit(),
    child: Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: ProofSpin()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.margin),
              child: Column(
                children: [
                  SizedBox(
                    height: 216,
                    child: BlocBuilder<SetupCubit, SetupState>(
                      builder: (context, s) => NativePicker(
                        min: SetupCubit.minPlayers,
                        max: SetupCubit.maxPlayers,
                        value: s.count,
                        onChanged: context.read<SetupCubit>().countChanged,
                      ),
                    ),
                  ),
                  const SizedBox(height: Tokens.s8),
                  BlocBuilder<SetupCubit, SetupState>(
                    builder: (_, s) => _Pill('Players: ${s.count}'),
                  ),
                  BlocSelector<ProofCubit, ProofState, String>(
                    selector: (s) => s.lastTap,
                    builder: (_, v) => _Pill('Last tap: $v'),
                  ),
                  BlocSelector<ProofCubit, ProofState, String>(
                    selector: (s) => s.frames,
                    builder: (_, v) => _Pill(v.isEmpty ? 'Frames: -' : v),
                  ),
                  _Pill(
                    'Reduce motion: ${MediaQuery.disableAnimationsOf(context) ? 'on' : 'off'}',
                  ),
                  BlocSelector<ProofCubit, ProofState, int>(
                    selector: (s) => s.flutterTaps,
                    builder: (context, n) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: context.read<ProofCubit>().flutterTapped,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Center(child: _Pill('Flutter taps: $n')),
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 184,
                    child: BlocBuilder<ProofCubit, ProofState>(
                      builder: (context, p) => NativeActionBar(
                        layout: p.choices
                            ? ActionBarLayout.row
                            : ActionBarLayout.stack,
                        items: p.choices
                            ? const [
                                ActionBarItem(
                                  id: 'truth',
                                  label: 'Truth',
                                  style: ActionBarStyle.choice,
                                ),
                                ActionBarItem(
                                  id: 'dare',
                                  label: 'Dare',
                                  style: ActionBarStyle.choice,
                                ),
                              ]
                            : [
                                ActionBarItem(
                                  id: 'spin',
                                  label: p.spinning ? 'Spinning…' : 'Spin',
                                  style: ActionBarStyle.primary,
                                  enabled: !p.spinning,
                                ),
                                const ActionBarItem(
                                  id: 'choices',
                                  label: 'Show choices',
                                ),
                                const ActionBarItem(
                                  id: 'end',
                                  label: 'End Session',
                                  style: ActionBarStyle.destructive,
                                ),
                              ],
                        onTap: (id) {
                          context.read<ProofCubit>().tapped(id);
                          if (id == 'end') {
                            context.read<SetupCubit>().countChanged(
                              SetupCubit.minPlayers,
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
        ],
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Tokens.s4),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Tokens.bgSurface,
        borderRadius: BorderRadius.circular(Tokens.r12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.s12,
          vertical: Tokens.s4,
        ),
        child: Text(text),
      ),
    ),
  );
}
