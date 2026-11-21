import 'package:flutter_test/flutter_test.dart';
import 'package:spinfolk/app/app.dart';
import 'package:spinfolk/core/di/injection.dart';

void main() {
  tearDown(getIt.reset);

  testWidgets('app boots to baseline page', (tester) async {
    configureDependencies();
    await tester.pumpWidget(const SpinfolkApp());
    await tester.pumpAndSettle();
    expect(find.text('Players: 8'), findsOneWidget);
  });
}
