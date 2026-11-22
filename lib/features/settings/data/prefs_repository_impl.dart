import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/failure.dart';
import '../domain/prefs.dart';
import '../domain/prefs_repository.dart';

/// The only keys the app may store. End Session never touches them.
const Set<String> prefsKeys = {'announce', 'voiceId', 'rate'};

@LazySingleton(as: PrefsRepository)
class PrefsRepositoryImpl implements PrefsRepository {
  PrefsRepositoryImpl(this._sp);
  final SharedPreferencesWithCache _sp;

  @override
  Prefs load() {
    try {
      return Prefs.sanitized(
        announce: _sp.getBool('announce'),
        voiceId: _sp.getString('voiceId'),
        rate: _sp.getDouble('rate'),
      );
    } on Object {
      // A stored value of the wrong type throws a TypeError.
      return const Prefs();
    }
  }

  @override
  Future<void> save(Prefs p) async {
    try {
      await _sp.setBool('announce', p.announce);
      await _sp.setDouble('rate', p.rate);
      final id = p.voiceId;
      await (id == null ? _sp.remove('voiceId') : _sp.setString('voiceId', id));
    } on Exception {
      throw const StorageFailure();
    }
  }
}
