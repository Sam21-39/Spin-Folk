import 'package:flutter_test/flutter_test.dart';
import 'package:spinfolk/features/session/domain/entities/session.dart';

import 'support/harness.dart';

void main() {
  testWidgets('nothing stored -> New Game', (tester) async {
    await pumpApp(tester);
    expect(find.text('New Game'), findsOneWidget);
  });

  testWidgets('stored session -> Resume', (tester) async {
    await pumpApp(
      tester,
      stored: Session(
        id: 'test',
        startedAtMs: 0,
        players: [for (var i = 0; i < 4; i++) Player(seat: i)],
      ),
    );
    expect(find.text('SESSION IN PROGRESS'), findsOneWidget);
  });
}
