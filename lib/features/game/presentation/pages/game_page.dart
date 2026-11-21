import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_navigator.dart';
import '../../../../app/tokens.dart';
import '../../../../app/ui.dart';
import '../../../../platform/native_action_bar.dart';
import '../../../session/domain/entities/session.dart';
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
        // D12 fallback, kept on purpose: the simulator showed native bars
        // painting over the sheet scrim, so bars drop while an overlay is up.
        final router = GoRouter.of(context);
        return ListenableBuilder(
          listenable: router.routerDelegate,
          builder: (context, _) => PageFrame(
            child: _Game(
              st,
              covered:
                  router.routerDelegate.currentConfiguration.uri.path !=
                  '/game',
            ),
          ),
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
                child: _Pill(round: session.round, n: session.playerCount),
              ),
              const SizedBox(width: Tokens.s12),
              const _SettingsButton(),
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
    if (st.spinning || o == null) {
      body = Container(
        constraints: const BoxConstraints(minHeight: 94),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Tokens.line),
          borderRadius: BorderRadius.circular(Tokens.r20),
        ),
        child: st.spinning
            ? const Text(
                'Waiting for the bottle…',
                style: TextStyle(color: Tokens.textTertiary, fontSize: 15),
              )
            : _legend(),
      );
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
  const _Pill({required this.round, required this.n});
  final int round, n;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Round $round · $n players',
    excludeSemantics: true,
    child: Container(
      constraints: const BoxConstraints(minHeight: Tokens.touch),
      padding: const EdgeInsets.symmetric(horizontal: Tokens.s16),
      decoration: ShapeDecoration(
        color: Tokens.bgRaised,
        shape: StadiumBorder(side: BorderSide(color: Tokens.line)),
      ),
      child: Center(
        widthFactor: 1,
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
    ),
  );
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton();

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Session and settings',
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.read<AppNavigator>().settings,
      child: Container(
        width: Tokens.touch,
        height: Tokens.touch,
        decoration: BoxDecoration(
          color: Tokens.bgRaised,
          shape: BoxShape.circle,
          border: Border.all(color: Tokens.line),
        ),
        alignment: Alignment.center,
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
      ),
    ),
  );
}
