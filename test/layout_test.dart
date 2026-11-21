import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spinfolk/app/app_navigator.dart';
import 'package:spinfolk/features/session/domain/entities/session.dart';
import 'package:spinfolk/features/setup/presentation/cubit/setup_cubit.dart';

import 'support/harness.dart';

final _long = 'W' * 40;

Session session(int n, Phase phase, {bool named = false, Mode? mode}) {
  final taker = 0, giver = n ~/ 2;
  return Session(
    id: 'test',
    startedAtMs: 0,
    players: [
      for (var i = 0; i < n; i++)
        Player(
          seat: i,
          name: named && (i == taker || i == giver) ? _long : null,
        ),
    ],
    phase: phase,
    outcome: phase == Phase.ready ? null : Outcome(taker: taker, giver: giver),
    mode: phase == Phase.challenge ? (mode ?? Mode.dare) : null,
  );
}

void main() {
  const cases = [
    (Size(375, 667), 1.0),
    (Size(375, 667), 1.35),
    (Size(375, 667), 3.12),
    (Size(320, 568), 1.0),
  ];

  for (final (size, scale) in cases) {
    final tag = '${size.width.toInt()}x${size.height.toInt()} @ $scale';

    Future<void> visit(
      WidgetTester tester,
      String name,
      Session? stored,
      Future<void> Function() go,
    ) async {
      await pumpApp(tester, stored: stored, size: size, textScale: scale);
      await go();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: name);
    }

    testWidgets('New Game, edit mode, Add Names ($tag)', (tester) async {
      await visit(tester, 'new', null, () async {});
      read<SetupCubit>(tester).countChanged(60);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      read<SetupCubit>(tester)
        ..namesOpened()
        ..draftChanged(0, _long);
      read<AppNavigator>(tester).names();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'names');
    });

    testWidgets('Resume ($tag)', (tester) async {
      await visit(
        tester,
        'resume',
        session(8, Phase.challenge, named: true),
        () async {},
      );
    });

    testWidgets('Game phases with 60 long names ($tag)', (tester) async {
      for (final phase in Phase.values) {
        await visit(
          tester,
          'game $phase',
          session(60, phase, named: true),
          () async {
            await tapBar(tester, 'resume');
          },
        );
      }
    });

    testWidgets('Game phases unnamed ($tag)', (tester) async {
      for (final phase in Phase.values) {
        await visit(tester, 'game $phase', session(8, phase), () async {
          await tapBar(tester, 'resume');
        });
      }
    });

    testWidgets('Spinning, sheet, end dialog, edit ($tag)', (tester) async {
      await visit(tester, 'spinning', session(60, Phase.ready), () async {
        await tapBar(tester, 'resume');
        await tester.pumpAndSettle();
        await tapBar(tester, 'spin');
        await tester.pump(const Duration(milliseconds: 200));
      });
      // let the spin finish, then the overlays
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      read<AppNavigator>(tester).settings();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'sheet');
      read<AppNavigator>(tester).confirmEnd();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'end');
      read<AppNavigator>(tester).game();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Sheet and end dialog from a ready game ($tag)', (
      tester,
    ) async {
      await visit(
        tester,
        'ready',
        session(60, Phase.ready, named: true),
        () async {
          await tapBar(tester, 'resume');
          await tester.pumpAndSettle();
          read<AppNavigator>(tester).settings();
        },
      );
      read<AppNavigator>(tester).confirmEnd();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'end');
      read<AppNavigator>(tester).game();
      await tester.pumpAndSettle();
      read<SetupCubit>(tester).seed(60, [for (var i = 0; i < 60; i++) _long]);
      read<AppNavigator>(tester).setup(editing: true);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'edit');
    });
  }
}
