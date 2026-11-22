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

  test('draft flow: open, change, save normalises and drops blanks', () {
    final c = SetupCubit()
      ..namesOpened()
      ..draftChanged(0, '  Riya ')
      ..draftChanged(1, '   ')
      ..draftChanged(2, 'Sam');
    expect(c.state.draft, {0: '  Riya ', 1: '   ', 2: 'Sam'});
    expect(c.state.names, isEmpty);
    c.namesSaved();
    expect(c.state.draft, isNull);
    expect(c.state.names, {0: 'Riya', 2: 'Sam'});
    expect(c.state.namedCount, 2);
  });

  test('cancel discards the draft', () {
    final c = SetupCubit()
      ..namesOpened()
      ..draftChanged(0, 'Riya')
      ..namesCancelled();
    expect(c.state.draft, isNull);
    expect(c.state.names, isEmpty);
  });

  test(
    'names survive count 8 -> 4 -> 8; namesForCount length follows count',
    () {
      final c = SetupCubit()
        ..namesOpened()
        ..draftChanged(6, 'Zed')
        ..namesSaved()
        ..countChanged(4);
      expect(c.state.namesForCount, hasLength(4));
      expect(c.state.namedCount, 0);
      c.countChanged(8);
      expect(c.state.namesForCount, hasLength(8));
      expect(c.state.namesForCount[6], 'Zed');
    },
  );

  test('seed and reset', () {
    final c = SetupCubit()..seed(3, ['A', null, 'C']);
    expect(c.state.count, 3);
    expect(c.state.names, {0: 'A', 2: 'C'});
    c.reset();
    expect(c.state, const SetupState());
  });

  test('out-of-range draftChanged and seed ignored', () {
    final c = SetupCubit()..draftChanged(0, 'x'); // no draft open
    expect(c.state.draft, isNull);
    c
      ..namesOpened()
      ..draftChanged(60, 'x')
      ..draftChanged(-1, 'x');
    expect(c.state.draft, isEmpty);
    c.seed(1, [null]);
    expect(c.state.count, 8);
    c.seed(61, []);
    expect(c.state.count, 8);
  });

  test('equality is by content', () {
    expect(const SetupState(names: {1: 'a'}), SetupState(names: {1: 'a'}));
    expect(const SetupState(names: {1: 'a'}) == const SetupState(), isFalse);
  });
}
