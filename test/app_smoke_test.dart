import 'package:flutter_test/flutter_test.dart';
import 'package:spinfolk/platform/native_action_bar.dart';
import 'package:spinfolk/features/session/domain/entities/session.dart';

import 'support/harness.dart';

void main() {
  testWidgets('nothing stored -> Home without a card, New game opens setup', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Spinfolk'), findsOneWidget);
    expect(find.textContaining('IN PROGRESS'), findsNothing);
    await tapBar(tester, 'new');
    await tester.pumpAndSettle();
    expect(find.text('New game'), findsOneWidget);
  });

  testWidgets('stored session -> card and an enabled Resume', (tester) async {
    await pumpApp(
      tester,
      stored: Session(
        id: 'test',
        startedAtMs: 0,
        players: [for (var i = 0; i < 4; i++) Player(seat: i)],
      ),
    );
    expect(find.textContaining('IN PROGRESS'), findsOneWidget);
    expect(
      tester
          .widgetList<NativeActionBar>(find.byType(NativeActionBar))
          .any((b) => b.items.any((i) => i.id == 'resume' && i.enabled)),
      isTrue,
    );
  });
}
