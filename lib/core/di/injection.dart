import 'dart:math';

import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../features/session/data/session_db.dart';
import '../../features/settings/data/prefs_repository_impl.dart';
import 'injection.config.dart';

final GetIt getIt = GetIt.instance;

@InjectableInit()
Future<GetIt> configureDependencies() => getIt.init();

@module
abstract class CoreModule {
  @lazySingleton
  Random get random => Random();

  @preResolve
  @singleton
  Future<Database> get database => openSessionDb();

  @preResolve
  @singleton
  Future<SharedPreferencesWithCache> get preferences =>
      SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(
          allowList: prefsKeys,
        ),
      );
}
