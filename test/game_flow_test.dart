import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spinfolk/app/app_navigator.dart';
import 'package:spinfolk/features/session/domain/entities/session.dart';
import 'package:spinfolk/features/session/domain/rules/selection.dart';
import 'package:spinfolk/features/session/presentation/bloc/session_bloc.dart';
import 'package:spinfolk/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:spinfolk/features/setup/presentation/cubit/setup_cubit.dart';

import 'package:spinfolk/features/settings/domain/prefs.dart';
import 'package:spinfolk/platform/adaptive_controls.dart';
import 'package:spinfolk/platform/announcer.dart';
import 'package:spinfolk/platform/native_bridge.dart';

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
      await tapBar(tester, 'new');
      await tester.pumpAndSettle();
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

      // Round log reflects Truth, Pass, Dare+Pass.
      await tapLabel(tester, 'Round 4 · $n players');
      await tester.pumpAndSettle();
      expect(find.text('Round log'), findsOneWidget);
      expect(find.text('3 rounds · 1 Truth · 0 Dare · 2 pass'), findsOneWidget);
      await tapLabel(tester, 'Done');
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Session and settings'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Players'), findsOneWidget);
      await tester.ensureVisible(find.text('End Session'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('End Session'));
      await tester.pumpAndSettle();
      expect(find.text('End this session?'), findsOneWidget);
      await tapBar(tester, 'confirm');
      await tester.pumpAndSettle();
      expect(find.text('Good game.'), findsOneWidget);
      expect(find.textContaining('3 rounds · $n players'), findsOneWidget);
      expect(repo.stored, isNull);
      expect(historyRepo().rows, hasLength(1));
      await tapBar(tester, 'done');
      await tester.pumpAndSettle();
      expect(find.text('Recent'), findsOneWidget);
      expect(find.textContaining('$n players · 3 rounds'), findsOneWidget);
      handle.dispose();
    });
  }

  testWidgets('Resume from Home continues the stored game', (tester) async {
    await pumpApp(tester, stored: storedSession(Phase.ready));
    expect(find.textContaining('IN PROGRESS'), findsOneWidget);
    expect(find.textContaining('Starting a new game ends'), findsOneWidget);
    await tapBar(tester, 'resume');
    await tester.pumpAndSettle();
    expect(find.text('Round 1 · 8 players'), findsOneWidget);
  });

  testWidgets('New game over an in-progress game archives it', (tester) async {
    final stored = storedSession(Phase.challenge);
    final repo = await pumpApp(
      tester,
      stored: Session(
        id: stored.id,
        startedAtMs: 0,
        players: stored.players,
        phase: Phase.challenge,
        outcome: stored.outcome,
        mode: Mode.truth,
        log: const [
          RoundEntry(round: 1, taker: 0, giver: 4, result: RoundResult.truth),
        ],
      ),
    );
    await tapBar(tester, 'new');
    await tester.pumpAndSettle();
    await tapBar(tester, 'start');
    await tester.pumpAndSettle();
    expect(find.text('Round 1 · 8 players'), findsOneWidget);
    expect(historyRepo().rows, hasLength(1));
    expect(repo.stored!.id, isNot('test'));
  });

  testWidgets('quick-count chip sets the count', (tester) async {
    await pumpApp(tester);
    await tapBar(tester, 'new');
    await tester.pumpAndSettle();
    await tapBar(tester, 'count:6');
    expect(read<SetupCubit>(tester).state.count, 6);
    await tapBar(tester, 'count:12');
    expect(read<SetupCubit>(tester).state.count, 12);
  });

  testWidgets('round log: pill and LAST card, Truth/Dare/Pass', (tester) async {
    await pumpApp(tester, stored: storedSession(Phase.ready, n: 8));
    await tapBar(tester, 'resume');
    await tester.pumpAndSettle();
    expect(find.text('LAST'), findsNothing); // legend while the log is empty
    await spin(tester);
    await tapBar(tester, 'truth');
    await tapBar(tester, 'next');
    await spin(tester);
    await tapBar(tester, 'pass'); // revealed -> pass
    await tester.pumpAndSettle();
    await spin(tester);
    await tapBar(tester, 'dare');
    await tapBar(tester, 'pass'); // dare then pass overwrites
    await tester.pumpAndSettle();
    expect(find.text('LAST'), findsOneWidget);
    expect(find.text('Passed · no penalty'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Round log'));
    await tester.pumpAndSettle();
    expect(find.text('Round log'), findsOneWidget);
    expect(find.text('3 rounds · 1 Truth · 0 Dare · 2 pass'), findsOneWidget);
    expect(find.text('Passed · no penalty'), findsNWidgets(3)); // 2 + LAST
    await tapLabel(tester, 'Done');
    await tester.pumpAndSettle();
    expect(find.text('Round log'), findsNothing);
  });

  testWidgets('Play again · same players starts round 1 with the names', (
    tester,
  ) async {
    final repo = await pumpApp(tester);
    await tapBar(tester, 'new');
    await tester.pumpAndSettle();
    read<SetupCubit>(tester)
      ..countChanged(4)
      ..namesOpened()
      ..draftChanged(1, 'Riya')
      ..namesSaved();
    await tester.pump();
    await tapBar(tester, 'start');
    await tester.pumpAndSettle();
    await spin(tester);
    await tapBar(tester, 'truth');
    read<AppNavigator>(tester).confirmEnd();
    await tester.pumpAndSettle();
    await tapBar(tester, 'confirm');
    await tester.pumpAndSettle();
    expect(find.text('Good game.'), findsOneWidget);
    expect(find.textContaining('Riya'), findsNothing); // only one round
    await tapBar(tester, 'again');
    await tester.pumpAndSettle();
    expect(find.text('Round 1 · 4 players'), findsOneWidget);
    expect(repo.stored!.players[1].name, 'Riya');
    expect(historyRepo().rows, hasLength(1));
  });

  testWidgets('failed start keeps names', (tester) async {
    final repo = await pumpApp(tester);
    await tapBar(tester, 'new');
    await tester.pumpAndSettle();
    read<SetupCubit>(tester)
      ..namesOpened()
      ..draftChanged(0, 'Riya')
      ..namesSaved();
    await tester.pumpAndSettle();
    repo.failWrites = true;
    await tapBar(tester, 'start');
    await tester.pumpAndSettle();
    expect(read<SetupCubit>(tester).state.names, {0: 'Riya'});
    expect(find.text('New game'), findsOneWidget);
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
    await tester.ensureVisible(find.text('Edit Players'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Players'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Players'), findsOneWidget); // page title
    expect(find.text('New game'), findsNothing);
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
    await tester.ensureVisible(find.text('Edit Players'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Players'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Players'), findsOneWidget); // still the sheet row
    expect(find.text('Session'), findsOneWidget);
  });

  testWidgets('names flow', (tester) async {
    await pumpApp(tester);
    await tapBar(tester, 'new');
    await tester.pumpAndSettle();
    expect(find.text('Add names'), findsOneWidget);
    await tester.tap(find.text('Add names'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, 'Riya');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Edit names'), findsOneWidget);
    expect(find.text('1 named'), findsOneWidget);

    await tester.tap(find.text('Edit names'));
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

  testWidgets('after End, New game shows no names', (tester) async {
    await pumpApp(tester);
    await tapBar(tester, 'new');
    await tester.pumpAndSettle();
    read<SetupCubit>(tester)
      ..namesOpened()
      ..draftChanged(0, 'Riya')
      ..namesSaved();
    await tester.pumpAndSettle();
    expect(find.text('Edit names'), findsOneWidget);
    await tapBar(tester, 'start');
    await tester.pumpAndSettle();
    read<AppNavigator>(tester).confirmEnd();
    await tester.pumpAndSettle();
    await tapBar(tester, 'confirm'); // no rounds: nothing saved, Home
    await tester.pumpAndSettle();
    expect(historyRepo().rows, isEmpty);
    await tapBar(tester, 'new');
    await tester.pumpAndSettle();
    expect(find.text('New game'), findsOneWidget);
    expect(find.text('Add names'), findsOneWidget);
  });

  group('announcements', () {
    Future<void> resumeAndSpin(WidgetTester tester, {Prefs? prefs}) async {
      await pumpApp(
        tester,
        stored: storedSession(Phase.ready),
        prefs: prefs ?? const Prefs(),
      );
      await tapBar(tester, 'resume');
      await tester.pumpAndSettle();
      await spin(tester);
    }

    String spokenOnScreen(WidgetTester tester) {
      final t =
          find
                  .byWidgetPredicate(
                    (w) =>
                        w is Text &&
                        (w.data ?? '').startsWith('“') &&
                        (w.data ?? '').endsWith('”'),
                  )
                  .evaluate()
                  .single
                  .widget
              as Text;
      final d = t.data!;
      return d.substring(1, d.length - 1);
    }

    testWidgets('live reveal speaks, Replay repeats, mode line on Replay', (
      tester,
    ) async {
      final h = tester.ensureSemantics();
      await resumeAndSpin(tester);
      expect(find.bySemanticsLabel('Replay announcement'), findsOneWidget);
      var calls = native.named('speech.speak');
      expect(calls, hasLength(1));
      expect((calls.single.arguments as Map)['text'], spokenOnScreen(tester));

      await tester.tap(find.bySemanticsLabel('Replay announcement'));
      await tester.pump();
      await tester.pump();
      expect(native.named('speech.speak'), hasLength(2));

      await tapBar(tester, 'truth');
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Replay announcement'), findsOneWidget);
      await tester.ensureVisible(find.bySemanticsLabel('Replay announcement'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Replay announcement'));
      await tester.pump();
      await tester.pump();
      calls = native.named('speech.speak');
      expect(calls, hasLength(3));
      expect((calls.last.arguments as Map)['text'], endsWith('chose Truth.'));
      h.dispose();
    });

    testWidgets('voice failure replaces the row until the next round', (
      tester,
    ) async {
      final h = tester.ensureSemantics();
      await pumpApp(tester, stored: storedSession(Phase.ready));
      native.failSpeak = true;
      await tapBar(tester, 'resume');
      await tester.pumpAndSettle();
      await spin(tester);
      expect(find.text(Announcer.unavailableText), findsOneWidget);
      expect(find.bySemanticsLabel('Replay announcement'), findsNothing);
      await tapBar(tester, 'pass');
      await tester.pumpAndSettle();
      expect(find.text(Announcer.unavailableText), findsNothing);
      h.dispose();
    });

    testWidgets('hide mid-spin reveals without speaking', (tester) async {
      final h = tester.ensureSemantics();
      await pumpApp(tester, stored: storedSession(Phase.ready));
      await tapBar(tester, 'resume');
      await tester.pumpAndSettle();
      await tapBar(tester, 'spin');
      await tester.pump(const Duration(milliseconds: 300));
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      addTearDown(() {
        tester.binding
          ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
          ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      });
      await tester.pump();
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp('^Taker .*, Giver .*')),
        findsOneWidget,
      );
      expect(native.named('speech.speak'), isEmpty);
      h.dispose();
    });

    testWidgets('settings sheet drives prefs', (tester) async {
      await resumeAndSpin(tester);
      native.voices = [
        {'id': 'a', 'name': 'Amy', 'language': 'en-US', 'quality': 'enhanced'},
        {'id': 'b', 'name': 'Bob', 'language': 'en-US', 'quality': 'default'},
      ];
      await tester.tap(find.bySemanticsLabel('Session and settings'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      for (final t in ['Announcements', 'Voice', 'Speed', 'Play sample']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(native.named('speech.voices'), hasLength(1));

      expect(
        tester.getSemantics(find.bySemanticsLabel('Announcements')),
        matchesSemantics(
          label: 'Announcements',
          hasToggledState: true,
          isToggled: true,
          hasTapAction: true,
        ),
      );
      tester.semantics.tap(find.semantics.byLabel('Announcements'));
      await tester.pump();
      await tester.pump();
      expect(prefsRepo.saved.last.announce, isFalse);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Announcements')),
        matchesSemantics(
          label: 'Announcements',
          hasToggledState: true,
          isToggled: false,
          hasTapAction: true,
        ),
      );

      final slider = tester.widget<NativeSlider>(find.byType(NativeSlider));
      final before = prefsRepo.saved.length;
      slider.onChanged(0.6);
      await tester.pump();
      expect(find.text('Fast'), findsOneWidget);
      expect(prefsRepo.saved.length, before);
      slider.onChangeEnd(0.6);
      await tester.pump();
      expect(prefsRepo.saved.last.rate, 0.6);

      await tester.tap(find.text('Voice'));
      await tester.pump();
      expect(find.text('Amy (Enhanced)'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);
      await tester.tap(find.text('Bob'));
      await tester.pump();
      expect(find.text('Bob ›'), findsOneWidget);
      expect(prefsRepo.saved.last.voiceId, 'b');

      final speaks = native.named('speech.speak').length;
      await tester.tap(find.text('Play sample'));
      await tester.pump();
      await tester.pump();
      final c = native.named('speech.speak');
      expect(c, hasLength(speaks + 1));
      expect((c.last.arguments as Map)['text'], Announcer.sampleLine);
    });

    testWidgets('End Session leaves prefs alone', (tester) async {
      await resumeAndSpin(tester);
      await tapBar(tester, 'truth');
      read<SetupCubit>(tester); // harness sanity: providers present
      await read<SettingsCubit>(tester).announceToggled(false);
      final saved = prefsRepo.saved.length;
      read<AppNavigator>(tester).confirmEnd();
      await tester.pumpAndSettle();
      await tapBar(tester, 'confirm');
      await tester.pumpAndSettle();
      expect(read<SessionBloc>(tester).state, isNot(isA<SessionActive>()));
      expect(prefsRepo.saved.length, saved);
      expect(prefsRepo.stored.announce, isFalse);
      expect(native.named('speech.stop'), isNotEmpty);
    });
  });

  testWidgets('Live Activity link resumes the game, not Home', (tester) async {
    final id = 'ab' * 16;
    final stored = Session(
      id: id,
      startedAtMs: 0,
      players: [for (var i = 0; i < 4; i++) Player(seat: i)],
    );
    await pumpApp(tester, stored: stored);
    expect(read<SessionBloc>(tester).state, isA<ResumePrompt>());
    await native.send('url.open', {'sessionId': id});
    await tester.pumpAndSettle();
    expect(read<SessionBloc>(tester).state, isA<SessionActive>());
    expect(find.text('Round 1 · 4 players'), findsOneWidget);
  });

  testWidgets('sheet line only when Live Activities are off', (tester) async {
    const line = 'Lock Screen updates are off in iOS Settings.';
    await pumpApp(tester, stored: storedSession(Phase.ready));
    await tapBar(tester, 'resume');
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Session and settings'));
    await tester.pumpAndSettle();
    expect(find.text(line), findsNothing);
    read<SettingsCubit>(tester).activityStatusChanged(ActivityStatus.disabled);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(line));
    expect(find.text(line), findsOneWidget);
    read<SettingsCubit>(tester)
        .activityStatusChanged(ActivityStatus.unsupported);
    await tester.pumpAndSettle();
    expect(find.text(line), findsNothing);
    expect(
      find.text("Lock Screen updates aren't available on this device."),
      findsOneWidget,
    );
  });

  testWidgets('activity disabled via channel: line shows, loop unaffected', (
    tester,
  ) async {
    const line = 'Lock Screen updates are off in iOS Settings.';
    await pumpApp(tester, stored: storedSession(Phase.ready, n: 8));
    native.activityState = 'disabled'; // pumpApp installs a fresh fake
    await tapBar(tester, 'resume');
    await tester.pumpAndSettle();
    await spin(tester);
    await tapBar(tester, 'truth');
    await tapBar(tester, 'next');
    await tester.pumpAndSettle();
    expect(read<SessionBloc>(tester).state, isA<SessionActive>());
    expect((read<SessionBloc>(tester).state as SessionActive).session.round, 2);
    await tester.tap(find.bySemanticsLabel('Session and settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(line));
    expect(find.text(line), findsOneWidget);
  });
}
