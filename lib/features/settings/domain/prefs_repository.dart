import 'prefs.dart';

abstract interface class PrefsRepository {
  /// Never throws; unreadable values fall back to defaults.
  Prefs load();

  /// Throws StorageFailure.
  Future<void> save(Prefs prefs);
}
