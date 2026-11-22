import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_navigator.dart';
import '../../../../app/tokens.dart';
import '../../../../app/ui.dart';
import '../cubit/setup_cubit.dart';

class AddNamesPage extends StatelessWidget {
  const AddNamesPage({required this.editing, super.key});
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final nav = context.read<AppNavigator>();
    final cubit = context.read<SetupCubit>();
    return Scaffold(
      backgroundColor: Tokens.bgBase,
      body: BlocSelector<SetupCubit, SetupState, (int, bool)>(
        selector: (s) => (s.count, s.draft != null),
        builder: (context, sel) {
          final (count, open) = sel;
          if (!open) return const SizedBox.shrink();
          // Read once per row: typing must not rebuild the list.
          final draft = cubit.state.draft!;
          return PageFrame(
            child: Column(
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () {
                            cubit.namesCancelled();
                            nav.setup(editing: editing);
                          },
                          child: Text(
                            'Cancel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textScaler: besideIsland(context),
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        'Names',
                        style: Tokens.headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textScaler: besideIsland(context),
                      ),
                    ),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            cubit.namesSaved();
                            nav.setup(editing: editing);
                          },
                          child: Text(
                            'Done',
                            style: TextStyle(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textScaler: besideIsland(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: Tokens.s12),
                          child: Text(
                            'Clockwise from Player 1. Blank stays numbered. '
                            'Matching names get their seat number added.',
                            style: TextStyle(
                              color: Tokens.textSecondary,
                              fontSize: 15,
                              height: 21 / 15,
                            ),
                          ),
                        ),
                        Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: Tokens.bgSurface,
                            border: Border.all(color: Tokens.line),
                            borderRadius: BorderRadius.circular(Tokens.r20),
                          ),
                          child: Column(
                            children: [
                              for (var seat = 0; seat < count; seat++) ...[
                                if (seat > 0)
                                  const ColoredBox(
                                    color: Tokens.line,
                                    child: SizedBox(
                                      height: 1,
                                      width: double.infinity,
                                    ),
                                  ),
                                _NameRow(
                                  seat: seat,
                                  initial: draft[seat] ?? '',
                                  onChanged: (t) => cubit.draftChanged(seat, t),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: Tokens.s12),
                          child: Text(
                            'Shown in game as “Riya · P1”.',
                            style: Tokens.footnote,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NameRow extends StatelessWidget {
  const _NameRow({
    required this.seat,
    required this.initial,
    required this.onChanged,
  });
  final int seat;
  final String initial;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 54),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: Tokens.bgRaised,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text('${seat + 1}', style: Tokens.numeral(14)),
          ),
          const SizedBox(width: Tokens.s12),
          Expanded(
            child: Semantics(
              label: 'Name for player ${seat + 1}',
              child: TextFormField(
                key: ValueKey(seat),
                initialValue: initial,
                onChanged: onChanged,
                inputFormatters: [LengthLimitingTextInputFormatter(40)],
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                cursorColor: Tokens.taker,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Player ${seat + 1}',
                  hintStyle: Tokens.body.copyWith(color: Tokens.textTertiary),
                ),
                style: Tokens.body,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
