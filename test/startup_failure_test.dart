import 'package:flutter_test/flutter_test.dart';
import 'package:spinfolk/main.dart';

void main() {
  testWidgets('init failure renders the fallback notice', (tester) async {
    await bootstrap(() => throw StateError('db newer'));
    await tester.pump();
    expect(
      find.textContaining("Couldn't open your saved games"),
      findsOneWidget,
    );
  });
}
