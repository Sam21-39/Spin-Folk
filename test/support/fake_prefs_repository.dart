import 'dart:async';

import 'package:spinfolk/core/failure.dart';
import 'package:spinfolk/features/settings/domain/prefs.dart';
import 'package:spinfolk/features/settings/domain/prefs_repository.dart';

class FakePrefsRepository implements PrefsRepository {
  Prefs stored = const Prefs();
  bool failWrites = false;

  /// Holds saves until completed; the failure decision is taken at call time.
  Completer<void>? gate;
  final List<Prefs> saved = [];

  @override
  Prefs load() => stored;

  @override
  Future<void> save(Prefs prefs) async {
    final fail = failWrites;
    await gate?.future;
    if (fail) throw const StorageFailure();
    saved.add(prefs);
    stored = prefs;
  }
}
