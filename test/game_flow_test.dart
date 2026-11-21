import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spinfolk/app/app_navigator.dart';
import 'package:spinfolk/features/session/domain/entities/session.dart';
import 'package:spinfolk/features/session/domain/rules/selection.dart';
import 'package:spinfolk/features/session/presentation/bloc/session_bloc.dart';
import 'package:spinfolk/features/setup/presentation/cubit/setup_cubit.dart';

import 'support/harness.dart';

const settle = Duration(milliseconds: 100);

Session storedSession(Phase phase, {int n = 8}) => Session(
  id: 'test',
  startedAtMs: 0,
  players: [for (var i = 0; i < n; i++) Player(seat: i)],
  phase: phase,
  outcome: phase == Phase.ready ? null : const Outcome(taker: 0, giver: 4),
  mode: phase == Phase.challenge ? Mode.truth : null,
);

Future<void> spin(WidgetTester tester) async {
  await tapBar(tester, 'spin');
  await tester.pumpAndSettle(settle);
}

void main() {
  for (final n in [2, 3, 5, 7, 59, 60]) {
    testWidgets('complete loop n=$n', (tester) async {
      final handle = tester.ensureSemantics();
      final repo = await pumpApp(tester);
      read<SetupCubit>(tester).countChanged(n);
      await tester.pump();

      await tapBar(tester, 'start');
      await tester.pumpAndSettle();
      expect(find.text('Round 1 · $n players'), findsOneWidget);
      expect(repo.stored!.isValid, isTrue);

      await tapBar(tester, 'spin');
      expect(find.text('Waiting for the bottle…'), findsOneWidget);
      expect(find.textContaining('TAKER'), findsNothing);
      await tester.pumpAndSettle(settle);
      expect(
        find.bySemanticsLabel(RegExp('^Taker .*, Giver .*')),
        findsOneWidget,
      );
      expect(repo.stored!.isValid, isTrue);

      await tapBar(tester, 'truth');
      expect(find.textContaining('a question, out loud.'), findsOneWidget);
      expect(repo.stored!.isValid, isTrue);

      await tapBar(tester, 'next');
      await tester.pumpAndSettle();
      expect(find.textContaining('Round 2'), findsOneWidget);

      await spin(tester);
      await tapBar(tester, 'pass');
      await tester.pumpAndSettle();
      expect(find.textContaining('Round 3'), findsOneWidget);
      expect(repo.stored!.isValid, isTrue);

      await spin(tester);
      await tapBar(tester, 'dare');
      expect(find.textContaining('a dare, out loud.'), findsOneWidget);
      await tapBar(tester, 'pass');
      await tester.pumpAndSettle();
      expect(find.textContaining('Round 4'), findsOneWidget);
      expect(repo.stored!.isValid, isTrue);

      await tester.tap(find.bySemanticsLabel('Session and settings'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Players'), findsOneWidget);
      await tester.tap(find.text('End Session'));
      await tester.pumpAndSettle();
      expect(find.text('End this session?'), findsOneWidget);
      await tapBar(tester, 'end');
      await tester.pumpAndSettle();
      expect(find.text('New Game'), findsOneWidget);
      expect(repo.stored, isNull);
      handle.dispose();
    });
  }

  testWidgets('End from Resume asks first; Cancel returns', (tester) async {
    final repo = await pumpApp(tester, stored: storedSession(Phase.ready));
    expect(find.text('SESSION IN PROGRESS'), findsOneWidget);
    await tapBar(tester, 'end');
    await tester.pumpAndSettle();
    expect(find.text('End this session?'), findsOneWidget);
    await tapBar(tester, 'cancel');
    await tester.pumpAndSettle();
    expect(find.text('SESSION IN PROGRESS'), findsOneWidget);
    await tapBar(tester, 'end');
    await tester.pumpAndSettle();
    await tapBar(tester, 'end');
    await tester.pumpAndSettle();
    expect(find.text('New Game'), findsOneWidget);
    expect(repo.stored, isNull);
  });

  testWidgets('End from Resume: barrier tap returns to Resume', (tester) async {
    await pumpApp(tester, stored: storedSession(Phase.ready));
    await tapBar(tester, 'end');
    await tester.pumpAndSettle();
    expect(find.text('End this session?'), findsOneWidget);
    await tester.tapAt(const Offset(195, 20));
    await tester.pumpAndSettle();
    expect(find.text('SESSION IN PROGRESS'), findsOneWidget);
    expect(find.text('End this session?'), findsNothing);
  });

  testWidgets('failed start keeps names', (tester) async {
    final repo = await pumpApp(tester);
    read<SetupCubit>(tester)
      ..namesOpened()
      ..draftChanged(0, 'Riya')
      ..namesSaved();
    await tester.pumpAndSettle();
    repo.failWrites = true;
    await tapBar(tester, 'start');
    await tester.pumpAndSettle();
    expect(read<SetupCubit>(tester).state.names, {0: 'Riya'});
    expect(find.text('New Game'), findsOneWidget);
  });

  testWidgets('Spin to Reveal: no ghost of the waiting panel', (tester) async {
    await pumpApp(tester, stored: storedSession(Phase.ready));
    await tapBar(tester, 'resume');
    await tester.pumpAndSettle();
    await tapBar(tester, 'spin');
    expect(find.text('Waiting for the bottle…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6)); // spin completes
    await tester.pump(); // bloc emits, switcher starts
    // Outermost fade inside the switcher is the switcher's own.
    double opacity(Finder f) {
      if (f.evaluate().isEmpty) return 0;
      final own = find.ancestor(
        of: f.first,
        matching: find.descendant(
          of: find.byType(AnimatedSwitcher),
          matching: find.byType(FadeTransition),
        ),
      );
      return tester.widget<FadeTransition>(own.last).opacity.value;
    }

    final waiting = find.text('Waiting for the bottle…');
    final revealed = find.textContaining('TAKER');
    for (var t = 0; t < 400; t += 20) {
      // Sequential fades: never both visible, so no ghosting.
      expect(opacity(waiting) * opacity(revealed), 0, reason: 'at ${t}ms');
      if (t == 160) expect(opacity(waiting), 0);
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
  });

  testWidgets('Reduce Motion spin reveals the seeded outcome', (tester) async {
    await pumpApp(tester, stored: storedSession(Phase.ready), seed: 5);
    await tapBar(tester, 'resume');
    await tester.pumpAndSettle();
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    await tester.pump();
    await tapBar(tester, 'spin');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.text('Waiting for the bottle…'), findsNothing);
    final o =
        (read<SessionBloc>(tester).state as SessionActive).session.outcome;
    expect(o, pickRoles(8, Random(5)));
  });

  testWidgets('Edit Players keeps round, changes count', (tester) async {
    await pumpApp(tester, stored: storedSession(Phase.ready));
    await tapBar(tester, 'resume');
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Session and settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Players'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Players'), findsOneWidget); // page title
    expect(find.text('New Game'), findsNothing);
    read<SetupCubit>(tester).countChanged(5);
    await tester.pump();
    await tapBar(tester, 'save');
    await tester.pumpAndSettle();
    expect(find.text('Round 1 · 5 players'), findsOneWidget);
  });

  testWidgets('Edit Players row is inert once revealed', (tester) async {
    await pumpApp(tester, stored: storedSession(Phase.revealed));
    await tapBar(tester, 'resume');
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Session and settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Players'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Players'), findsOneWidget); // still the sheet row
    expect(find.text('Session'), findsOneWidget);
  });

  testWidgets('names flow', (tester) async {
    await pumpApp(tester);
    expect(find.textContaining('Add Names'), findsOneWidget);
    await tester.tap(find.textContaining('Add Names'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, 'Riya');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Names · 1 named'), findsOneWidget);

    await tester.tap(find.textContaining('Edit Names'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, 'Changed');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(read<SetupCubit>(tester).state.names, {0: 'Riya'});
  });

  testWidgets('storage failure on spin shows banner, Spin re-enabled', (
    tester,
  ) async {
    final repo = await pumpApp(tester, stored: storedSession(Phase.ready));
    await tapBar(tester, 'resume');
    await tester.pumpAndSettle();
    repo.failWrites = true;
    await tapBar(tester, 'spin');
    await tester.pumpAndSettle(settle);
    expect(find.text("Couldn't save. Try again."), findsOneWidget);
    await tapBar(tester, 'spin'); // fails if the item is disabled
    repo.failWrites = false;
  });

  testWidgets('after End, New Game shows no names', (tester) async {
    await pumpApp(tester);
    read<SetupCubit>(tester)
      ..namesOpened()
      ..draftChanged(0, 'Riya')
      ..namesSaved();
    await tester.pumpAndSettle();
    expect(find.textContaining('Edit Names'), findsOneWidget);
    await tapBar(tester, 'start');
    await tester.pumpAndSettle();
    read<AppNavigator>(tester).confirmEnd();
    await tester.pumpAndSettle();
    await tapBar(tester, 'end');
    await tester.pumpAndSettle();
    expect(find.text('New Game'), findsOneWidget);
    expect(find.textContaining('Add Names'), findsOneWidget);
  });
}
