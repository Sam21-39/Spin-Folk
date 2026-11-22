import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_navigator.dart';
import '../../../../app/tokens.dart';
import '../../../../app/ui.dart';
import '../../../../platform/glass_button.dart';
import '../../../../platform/native_action_bar.dart';
import '../../../session/domain/entities/session.dart';
import '../../../history/domain/rules/history_labels.dart';
import '../../../session/domain/rules/labels.dart';
import '../../../session/presentation/bloc/session_bloc.dart';
import '../widgets/role_cards.dart';
import '../widgets/spin_stage.dart';

class GamePage extends StatelessWidget {
  const GamePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Tokens.bgBase,
    body: BlocBuilder<SessionBloc, SessionState>(
      builder: (context, st) {
        if (st is! SessionActive) return const SizedBox.shrink();
        // Only the top route shows native views (D13).
        return TopRoute(
          path: '/game',
          builder: (context, covered) =>
              PageFrame(child: _Game(st, covered: covered)),
        );
      },
    ),
  );
}

class _Game extends StatelessWidget {
  const _Game(this.st, {required this.covered});
  final SessionActive st;
  final bool covered;

  Session get session => st.session;

  void _tap(BuildContext context, String id) {
    final bloc = context.read<SessionBloc>();
    switch (id) {
      case 'spin':
        bloc.add(const SpinRequested());
      case 'truth':
        bloc.add(const ModeChosen(Mode.truth));
      case 'dare':
        bloc.add(const ModeChosen(Mode.dare));
      case 'pass':
        bloc.add(const Passed());
      case 'next':
        bloc.add(const NextRoundRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final sc = barScale(context);
    final phase = session.phase;
    final spinning = st.spinning;
    final f = spinning || phase == Phase.ready
        ? 0.70
        : (phase == Phase.revealed ? 0.56 : 0.44);

    Widget bar(
      List<ActionBarItem> items, [
      ActionBarLayout layout = ActionBarLayout.stack,
    ]) => covered
        ? const SizedBox.shrink()
        : NativeActionBar(
            items: items,
            layout: layout,
            onTap: (id) => _tap(context, id),
          );
    final passBar = bar(const [ActionBarItem(id: 'pass', label: 'Pass')]);

    final (mainBar, rowB) = switch ((phase, spinning)) {
      (_, true) => (
        bar(const [
          ActionBarItem(
            id: 'spin',
            label: 'Spinning…',
            style: ActionBarStyle.primary,
            enabled: false,
          ),
        ]),
        _note(
          context,
          'Result is already locked in. Leaving the app won’t change it.',
        ),
      ),
      (Phase.ready, _) => (
        bar(const [
          ActionBarItem(
            id: 'spin',
            label: 'Spin',
            style: ActionBarStyle.primary,
          ),
        ]),
        const SizedBox.shrink(),
      ),
      (Phase.revealed, _) => (
        bar(const [
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
        ], ActionBarLayout.row),
        Row(
          children: [
            Expanded(
              child: Text(
                'Anyone can pass. No penalty.',
                style: Tokens.footnote,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textScaler: besideIsland(context),
              ),
            ),
            SizedBox(width: Tokens.passWidth, child: passBar),
          ],
        ),
      ),
      (Phase.challenge, _) => (
        bar(const [
          ActionBarItem(
            id: 'next',
            label: 'Next Round',
            style: ActionBarStyle.primary,
          ),
        ], ActionBarLayout.row),
        const SizedBox.shrink(),
      ),
    };
    final challenge = phase == Phase.challenge && !spinning;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: Tokens.s8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: _Pill(
                  round: session.round,
                  n: session.playerCount,
                  covered: covered,
                ),
              ),
              const SizedBox(width: Tokens.s12),
              _SettingsButton(covered: covered),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final dial = min(c.maxWidth, c.maxHeight * f).clamp(120.0, 350.0);
              return Column(
                children: [
                  AnimatedContainer(
                    duration: reduce ? Duration.zero : Tokens.panelEnter,
                    width: dial,
                    height: dial,
                    margin: const EdgeInsets.only(top: Tokens.s8),
                    child: const SpinStage(),
                  ),
                  const SizedBox(height: Tokens.s12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: AnimatedSwitcher(
                        duration: reduce ? Duration.zero : Tokens.panelEnter,
                        // Sequential fades, top-aligned: no ghost overlap.
                        switchInCurve: const Interval(
                          0.5,
                          1,
                          curve: Curves.easeOut,
                        ),
                        switchOutCurve: const Interval(
                          0.5,
                          1,
                          curve: Curves.easeIn,
                        ),
                        layoutBuilder: (current, previous) => Stack(
                          alignment: Alignment.topCenter,
                          children: [...previous, ?current],
                        ),
                        child: SizedBox(
                          key: ValueKey('${phase.name}-$spinning'),
                          width: double.infinity,
                          child: _panel(context),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: Tokens.s8),
          child: SizedBox(
            height:
                (Tokens.barPrimary + Tokens.barGap + Tokens.barSecondary) * sc,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  height: Tokens.barPrimary * sc,
                  child: Row(
                    children: [
                      if (challenge) ...[
                        SizedBox(width: Tokens.passWidth, child: passBar),
                        const SizedBox(width: Tokens.barGap),
                      ],
                      Expanded(key: const ValueKey('main'), child: mainBar),
                    ],
                  ),
                ),
                const SizedBox(height: Tokens.barGap),
                SizedBox(height: Tokens.barSecondary * sc, child: rowB),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _note(BuildContext context, String text) => Center(
    child: Text(
      text,
      style: Tokens.footnote,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textScaler: besideIsland(context),
    ),
  );

  Widget _panel(BuildContext context) {
    final o = session.outcome;
    final Widget body;
    if (st.spinning) {
      body = Container(
        constraints: const BoxConstraints(minHeight: 94),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Tokens.line),
          borderRadius: BorderRadius.circular(Tokens.r20),
        ),
        child: const Text(
          'Waiting for the bottle…',
          style: TextStyle(color: Tokens.textTertiary, fontSize: 15),
        ),
      );
    } else if (o == null) {
      body = _ready(context);
    } else if (session.phase == Phase.revealed) {
      body = Column(
        children: [
          RoleCards(session: session),
          const SizedBox(height: Tokens.s12),
          _quote(),
        ],
      );
    } else {
      body = Column(
        children: [
          _challengeCard(o),
          const SizedBox(height: Tokens.s12),
          _quote(),
        ],
      );
    }
    final failure = st.failure;
    return Column(
      children: [
        if (failure != null) ...[
          NoticeBanner(failure.message),
          const SizedBox(height: Tokens.s12),
        ],
        body,
      ],
    );
  }

  Widget _quote() => Text(
    '“${speechLine(session)}”',
    textAlign: TextAlign.center,
    style: const TextStyle(
      color: Tokens.textSecondary,
      fontSize: 14,
      height: 19 / 14,
    ),
  );

  /// Ready panel: flick hint, then the "LAST" card (or the legend, no rounds).
  Widget _ready(BuildContext context) {
    final last = session.log.isEmpty ? null : session.log.last;
    return Column(
      children: [
        const Text(
          'Flick the bottle, or tap Spin.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Tokens.textSecondary, fontSize: 15),
        ),
        const SizedBox(height: Tokens.s12),
        if (last == null)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Tokens.line),
              borderRadius: BorderRadius.circular(Tokens.r20),
            ),
            child: _legend(),
          )
        else
          _lastCard(context, last),
      ],
    );
  }

  Widget _lastCard(BuildContext context, RoundEntry e) {
    final pass = e.result == RoundResult.pass;
    final giver = shortLabel(playerAt(session.players, e.giver));
    final taker = shortLabel(playerAt(session.players, e.taker));
    return Semantics(
      button: true,
      label: 'Round log',
      excludeSemantics: true,
      onTap: context.read<AppNavigator>().roundLog,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: context.read<AppNavigator>().roundLog,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Tokens.bgSurface,
            border: Border.all(color: Tokens.line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LAST',
                      style: Tokens.caption.copyWith(
                        color: Tokens.textTertiary,
                      ),
                    ),
                    const SizedBox(height: Tokens.s4),
                    if (pass)
                      Text(
                        resultLabel(e.result),
                        style: const TextStyle(
                          color: Tokens.textTertiary,
                          fontSize: 15,
                        ),
                      )
                    else
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: giver,
                              style: const TextStyle(color: Tokens.giver),
                            ),
                            const TextSpan(text: ' → '),
                            TextSpan(
                              text: taker,
                              style: const TextStyle(color: Tokens.taker),
                            ),
                            TextSpan(text: ' · ${resultLabel(e.result)}'),
                          ],
                          style: const TextStyle(
                            color: Tokens.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: Tokens.s8),
              Text(
                'Round log ›',
                style: const TextStyle(
                  color: Tokens.textTertiary,
                  fontSize: 14,
                ),
                textScaler: besideIsland(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legend() {
    Widget row(Color c, String bold, String rest) => Row(
      children: [
        Container(width: 10, height: 10, color: c),
        const SizedBox(width: Tokens.s12),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: bold,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: rest),
              ],
              style: const TextStyle(color: Tokens.textPrimary, fontSize: 15),
            ),
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          row(Tokens.taker, 'Neck', ' picks who takes the challenge'),
          const SizedBox(height: Tokens.s12),
          row(Tokens.giver, 'Base', ' points to who gives it'),
        ],
      ),
    );
  }

  Widget _challengeCard(Outcome o) {
    final dare = session.mode == Mode.dare;
    final giver = displayLabel(session.players[o.giver]);
    final taker = displayLabel(session.players[o.taker]);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Tokens.s24),
      decoration: BoxDecoration(
        color: Tokens.bgSurface,
        border: Border.all(color: Tokens.line),
        borderRadius: BorderRadius.circular(Tokens.r28),
      ),
      child: Column(
        children: [
          Text(
            'ROUND ${session.round} · ${dare ? 'DARE' : 'TRUTH'}',
            style: Tokens.caption.copyWith(color: Tokens.textTertiary),
          ),
          const SizedBox(height: 14),
          Text(dare ? 'Dare' : 'Truth', style: Tokens.numeral(40)),
          const SizedBox(height: 14),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: giver,
                  style: const TextStyle(
                    color: Tokens.giver,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(text: dare ? ' gives ' : ' asks '),
                TextSpan(
                  text: taker,
                  style: const TextStyle(
                    color: Tokens.taker,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: dare ? ' a dare, out loud.' : ' a question, out loud.',
                ),
              ],
              style: const TextStyle(
                color: Tokens.textPrimary,
                fontSize: 19,
                height: 26 / 19,
              ),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          const Text(
            'The app doesn’t write challenges. The group does.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Tokens.textTertiary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.round, required this.n, required this.covered});
  final int round, n;
  final bool covered;

  @override
  Widget build(BuildContext context) => GlassButton(
    label: 'Round $round · $n players',
    flat: covered,
    onPressed: context.read<AppNavigator>().roundLog,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Round $round',
                  style: const TextStyle(
                    color: Tokens.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(text: ' · '),
                TextSpan(text: '$n players'),
              ],
              style: const TextStyle(color: Tokens.textSecondary, fontSize: 15),
            ),
            maxLines: 1,
            textScaler: besideIsland(context),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          '›',
          style: TextStyle(color: Tokens.textTertiary, fontSize: 15),
        ),
      ],
    ),
  );
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.covered});
  final bool covered;

  @override
  Widget build(BuildContext context) => GlassButton(
    label: 'Session and settings',
    symbol: 'ellipsis',
    flat: covered,
    onPressed: context.read<AppNavigator>().settings,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Tokens.textPrimary,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    ),
  );
}
