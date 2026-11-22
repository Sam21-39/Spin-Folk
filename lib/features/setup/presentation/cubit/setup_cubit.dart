import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../session/domain/rules/labels.dart';

// Lets the simulator gate start at an exact player count (the native wheel
// cannot be set to 59 by automation). Normal builds get 8.
const int _envCount = int.fromEnvironment(
  'SPINFOLK_INITIAL_COUNT',
  defaultValue: 8,
);
const int _initialCount = _envCount < 2 ? 2 : (_envCount > 60 ? 60 : _envCount);

bool _sameMap(Map<int, String>? a, Map<int, String>? b) {
  if (a == null || b == null) return a == b;
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}

final class SetupState {
  const SetupState({
    this.count = _initialCount,
    this.names = const {},
    this.draft,
  });

  final int count;

  /// Seat -> normalised name; seats >= count are kept but unused.
  final Map<int, String> names;

  /// Non-null only while the Names page is open (raw text).
  final Map<int, String>? draft;

  List<String?> get namesForCount => [for (var i = 0; i < count; i++) names[i]];
  int get namedCount => namesForCount.whereType<String>().length;

  @override
  bool operator ==(Object other) =>
      other is SetupState &&
      other.count == count &&
      _sameMap(other.names, names) &&
      _sameMap(other.draft, draft);

  // XOR: equal maps hash alike whatever their insertion order.
  @override
  int get hashCode => Object.hash(
    count,
    names.entries.fold<int>(0, (h, e) => h ^ Object.hash(e.key, e.value)),
    draft?.length,
  );
}

@injectable
class SetupCubit extends Cubit<SetupState> {
  SetupCubit() : super(const SetupState());

  static const int minPlayers = 2;
  static const int maxPlayers = 60;

  bool _inRange(int count) => count >= minPlayers && count <= maxPlayers;

  /// Input comes from a native channel, so out-of-range values are ignored.
  void countChanged(int count) {
    if (!_inRange(count)) return;
    emit(SetupState(count: count, names: state.names, draft: state.draft));
  }

  void namesOpened() => emit(
    SetupState(
      count: state.count,
      names: state.names,
      draft: Map.of(state.names),
    ),
  );

  void draftChanged(int seat, String text) {
    final d = state.draft;
    if (d == null || seat < 0 || seat >= maxPlayers) return;
    emit(
      SetupState(
        count: state.count,
        names: state.names,
        draft: {...d, seat: text},
      ),
    );
  }

  void namesSaved() {
    final d = state.draft;
    if (d == null) return;
    final names = <int, String>{};
    for (final e in d.entries) {
      final n = normalizeName(e.value);
      if (n != null) names[e.key] = n;
    }
    emit(SetupState(count: state.count, names: names));
  }

  void namesCancelled() =>
      emit(SetupState(count: state.count, names: state.names));

  /// For Edit Players.
  void seed(int count, List<String?> names) {
    if (!_inRange(count)) return;
    emit(
      SetupState(
        count: count,
        names: {
          for (var i = 0; i < names.length && i < maxPlayers; i++)
            if (names[i] != null) i: names[i]!,
        },
      ),
    );
  }

  void reset() => emit(const SetupState());
}
