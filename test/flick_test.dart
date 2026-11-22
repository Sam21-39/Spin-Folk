import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spinfolk/features/game/presentation/widgets/dial_painter.dart';
import 'package:spinfolk/features/game/presentation/widgets/flick.dart';
import 'package:spinfolk/features/game/presentation/widgets/spin_stage.dart';
import 'package:spinfolk/features/session/domain/entities/session.dart';
import 'package:spinfolk/features/session/presentation/bloc/session_bloc.dart';

import 'support/harness.dart';

Session ready() => Session(
  id: 'test',
  startedAtMs: 0,
  players: [for (var i = 0; i < 8; i++) Player(seat: i)],
);

DialPainter painter(WidgetTester t) =>
    (t
            .widgetList<CustomPaint>(
              find.descendant(
                of: find.byType(SpinStage),
                matching: find.byType(CustomPaint),
              ),
            )
            .firstWhere((c) => c.painter is DialPainter)
            .painter!)
        as DialPainter;

void main() {
  group('pure', () {
    test('angleDelta is clockwise positive (y down)', () {
      expect(
        angleDelta(const Offset(0, -1), const Offset(1, 0)),
        closeTo(pi / 2, 1e-9),
      );
      expect(
        angleDelta(const Offset(1, 0), const Offset(0, -1)),
        closeTo(-pi / 2, 1e-9),
      );
      expect(angleDelta(const Offset(1, 0), const Offset(1, 0)), 0);
    });

    test('angularVelocity sign and centre guard', () {
      // Above the centre moving right = clockwise.
      expect(
        angularVelocity(const Offset(0, -60), const Offset(1500, 0)),
        closeTo(25, 1e-9),
      );
      expect(
        angularVelocity(const Offset(0, -60), const Offset(-1500, 0)),
        closeTo(-25, 1e-9),
      );
      expect(angularVelocity(const Offset(0, -7), const Offset(1500, 0)), 0);
      expect(angularVelocity(Offset.zero, const Offset(1500, 0)), 0);
    });

    test('wrapPi', () {
      expect(wrapPi(0), 0);
      expect(wrapPi(3 * pi), closeTo(pi, 1e-9));
      expect(wrapPi(-3 * pi), closeTo(pi, 1e-9));
      expect(wrapPi(2 * pi + 0.5), closeTo(0.5, 1e-9));
      expect(wrapPi(-0.5), closeTo(-0.5, 1e-9));
    });
  });

  Future<Offset> openGame(WidgetTester tester, {int seed = 1}) async {
    await pumpApp(tester, stored: ready(), seed: seed);
    await tapBar(tester, 'resume');
    await tester.pumpAndSettle();
    return tester.getCenter(find.byType(SpinStage));
  }

  testWidgets('a flick starts the spin', (tester) async {
    final c = await openGame(tester);
    await tester.flingFrom(
      c + const Offset(0, -60),
      const Offset(120, 0),
      1500,
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Waiting for the bottle…'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  });

  testWidgets('a slow release snaps back and stays ready', (tester) async {
    final c = await openGame(tester);
    final g = await tester.startGesture(c + const Offset(0, -60));
    await g.moveBy(const Offset(30, 0));
    await tester.pump();
    expect(painter(tester).drag.value, isNot(0));
    await tester.pump(const Duration(milliseconds: 500));
    await g.up();
    await tester.pumpAndSettle();
    expect(find.text('Waiting for the bottle…'), findsNothing);
    final s = read<SessionBloc>(tester).state as SessionActive;
    expect(s.session.phase, Phase.ready);
    expect(s.spinning, isFalse);
    expect(painter(tester).drag.value, 0);
  });

  testWidgets('a drag that starts on the rim does nothing', (tester) async {
    final c = await openGame(tester);
    await tester.flingFrom(
      c + const Offset(0, -165),
      const Offset(120, 0),
      1500,
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Waiting for the bottle…'), findsNothing);
    expect(painter(tester).drag.value, 0);
  });

  testWidgets('a flick while revealed does nothing', (tester) async {
    final c = await openGame(tester);
    await tapBar(tester, 'spin');
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    final before = (read<SessionBloc>(tester).state as SessionActive).session;
    expect(before.phase, Phase.revealed);
    await tester.flingFrom(
      c + const Offset(0, -60),
      const Offset(120, 0),
      1500,
    );
    await tester.pump();
    await tester.pump();
    final after = (read<SessionBloc>(tester).state as SessionActive);
    expect(after.session, before);
    expect(after.spinning, isFalse);
  });

  testWidgets('same seed: flick and Spin tap store the same outcome', (
    tester,
  ) async {
    var c = await openGame(tester, seed: 7);
    await tester.flingFrom(
      c + const Offset(0, -60),
      const Offset(-120, 0),
      900,
    );
    await tester.pump();
    await tester.pump();
    final viaFlick = (await _stored(tester));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    c = await openGame(tester, seed: 7);
    await tapBar(tester, 'spin');
    final viaTap = (await _stored(tester));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(viaFlick, isNotNull);
    expect(viaFlick, viaTap);
  });
}

Future<Outcome?> _stored(WidgetTester tester) async =>
    (read<SessionBloc>(tester).state as SessionActive).session.outcome;
