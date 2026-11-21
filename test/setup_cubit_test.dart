import 'package:flutter_test/flutter_test.dart';
import 'package:spinfolk/features/setup/presentation/cubit/setup_cubit.dart';

void main() {
  test('initial count is 8', () {
    expect(SetupCubit().state.count, 8);
  });

  test('accepts values in range including bounds', () {
    final c = SetupCubit();
    for (final n in [12, 2, 60]) {
      c.countChanged(n);
      expect(c.state.count, n);
    }
  });

  test('ignores out-of-range values', () {
    final c = SetupCubit()..countChanged(12);
    c
      ..countChanged(1)
      ..countChanged(61);
    expect(c.state.count, 12);
  });
}
