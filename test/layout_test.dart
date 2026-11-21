import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spinfolk/app/app_navigator.dart';
import 'package:spinfolk/features/history/presentation/cubit/history_cubit.dart';
import 'package:spinfolk/features/session/domain/entities/game_record.dart';
import 'package:spinfolk/features/session/domain/entities/session.dart';
import 'package:spinfolk/features/setup/presentation/cubit/setup_cubit.dart';

import 'package:spinfolk/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:spinfolk/platform/announcer.dart';

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

/// Session with [rounds] logged rounds, 60 players, long names on the ends.
Session played(int rounds, {int n = 60}) => Session(
  id: 'test',
  startedAtMs: 0,
  players: [
    for (var i = 0; i < n; i++)
      Player(seat: i, name: i == 0 || i == n ~/ 2 ? _long : null),
  ],
  round: rounds + 1,
  log: [
    for (var r = 1; r <= rounds; r++)
      RoundEntry(
        round: r,
        taker: r.isEven ? 0 : n ~/ 2,
        giver: r.isEven ? n ~/ 2 : 0,
        result: RoundResult.values[r % 3],
      ),
  ],
);

GameRecord record(String id, {int n = 60, int rounds = 8}) {
  final s = played(rounds, n: n);
  return GameRecord(
    id: id,
    startedAtMs: 0,
    endedAtMs: DateTime.now().millisecondsSinceEpoch - 3600 * 1000 * 24 * 40,
    players: s.players,
    rounds: s.log,
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

    testWidgets('New game, edit mode, Add Names ($tag)', (tester) async {
      await visit(tester, 'new', null, () async {
        read<AppNavigator>(tester).setup();
      });
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

    testWidgets('Home, empty and in progress ($tag)', (tester) async {
      await visit(tester, 'home', null, () async {});
      await visit(tester, 'home in progress', played(5, n: 8), () async {});
      await visit(tester, 'home with recent', played(5), () async {});
    });

    testWidgets('Home with Recent rows ($tag)', (tester) async {
      await pumpApp(
        tester,
        size: size,
        textScale: scale,
        history: [for (var i = 0; i < 5; i++) record('g$i')],
      );
      expect(tester.takeException(), isNull);
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

    testWidgets('Round log sheet, 60 rounds, long names ($tag)', (
      tester,
    ) async {
      await visit(tester, 'log', played(60), () async {
        await tapBar(tester, 'resume');
        await tester.pumpAndSettle();
        read<AppNavigator>(tester).roundLog();
      });
      // Also empty.
      await visit(tester, 'log empty', session(60, Phase.ready), () async {
        await tapBar(tester, 'resume');
        await tester.pumpAndSettle();
        read<AppNavigator>(tester).roundLog();
      });
    });

    testWidgets('Ready with LAST card, long names ($tag)', (tester) async {
      await visit(tester, 'ready last', played(3), () async {
        await tapBar(tester, 'resume');
      });
    });

    testWidgets('Session sheet ($tag)', (tester) async {
      await visit(tester, 'session', session(60, Phase.ready), () async {
        await tapBar(tester, 'resume');
        await tester.pumpAndSettle();
        read<AppNavigator>(tester).settings();
      });
    });

    testWidgets(
      'Voice sheet with a long voice list, Replay row, notice ($tag)',
      (tester) async {
        await visit(tester, 'revealed', session(8, Phase.revealed), () async {
          await tapBar(tester, 'resume');
        });
        expect(find.text('Replay'), findsOneWidget);
        await visit(tester, 'challenge', session(8, Phase.challenge), () async {
          await tapBar(tester, 'resume');
        });
        expect(find.text('Replay'), findsOneWidget);

        native.voices = [
          for (var i = 0; i < 12; i++)
            {
              'id': 'v$i',
              'name': i == 0 ? _long : 'Voice $i',
              'language': 'en-US',
              'quality': i.isEven ? 'enhanced' : 'default',
            },
        ];
        await read<SettingsCubit>(tester).opened();
        read<SettingsCubit>(tester).voiceRowTapped();
        read<AppNavigator>(tester).settings();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'voice sheet');
        await read<SettingsCubit>(tester).voiceSelected('v0');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'long voice name');
      },
    );

    testWidgets('Revealed with the voice notice ($tag)', (tester) async {
      await pumpApp(
        tester,
        stored: session(8, Phase.ready),
        size: size,
        textScale: scale,
      );
      native.failSpeak = true;
      await tapBar(tester, 'resume');
      await tester.pumpAndSettle();
      await tapBar(tester, 'spin');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text(Announcer.unavailableText), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Summary ($tag)', (tester) async {
      await visit(tester, 'summary', played(30), () async {
        await tapBar(tester, 'resume');
        await tester.pumpAndSettle();
        read<AppNavigator>(tester).confirmEnd();
        await tester.pumpAndSettle();
        await tapBar(tester, 'confirm');
      });
      expect(find.text('Good game.'), findsOneWidget);
    });

    testWidgets('History list, empty, detail, confirms, toast ($tag)', (
      tester,
    ) async {
      final games = [for (var i = 0; i < 5; i++) record('g$i')];
      await visit(tester, 'history', null, () async {
        read<AppNavigator>(tester).history();
      });
      await pumpApp(tester, size: size, textScale: scale, history: games);
      read<AppNavigator>(tester).history();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'history list');
      read<AppNavigator>(tester).confirmClear();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'clear all');
      read<AppNavigator>(tester).history();
      await tester.pumpAndSettle();
      read<AppNavigator>(tester).historyDetail('g0');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'detail');
      read<AppNavigator>(tester).confirmDelete('g0');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'delete confirm');
      read<AppNavigator>(tester).history();
      await tester.pumpAndSettle();
      await read<HistoryCubit>(tester).delete(['g1']);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Game deleted'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'toast');
      await read<HistoryCubit>(tester).delete(['g2', 'g3']);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('2 games deleted'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
