import 'dart:math';

import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'injection.config.dart';

final GetIt getIt = GetIt.instance;

// Synchronous until the first @preResolve dependency (Database, prefs) lands
// in a later phase; it then becomes Future<void> and main() awaits it.
@InjectableInit()
void configureDependencies() => getIt.init();

@module
abstract class CoreModule {
  @lazySingleton
  Random get random => Random();
}
