// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:math' as _i407;

import 'package:get_it/get_it.dart' as _i174;
import 'package:go_router/go_router.dart' as _i583;
import 'package:injectable/injectable.dart' as _i526;
import 'package:shared_preferences/shared_preferences.dart' as _i460;
import 'package:spinfolk/app/app_navigator.dart' as _i854;
import 'package:spinfolk/app/router.dart' as _i1010;
import 'package:spinfolk/core/di/injection.dart' as _i864;
import 'package:spinfolk/features/history/data/history_repository_impl.dart'
    as _i692;
import 'package:spinfolk/features/history/domain/history_repository.dart'
    as _i67;
import 'package:spinfolk/features/history/presentation/cubit/history_cubit.dart'
    as _i295;
import 'package:spinfolk/features/session/data/session_repository_impl.dart'
    as _i818;
import 'package:spinfolk/features/session/domain/session_repository.dart'
    as _i555;
import 'package:spinfolk/features/session/presentation/bloc/session_bloc.dart'
    as _i986;
import 'package:spinfolk/features/settings/data/prefs_repository_impl.dart'
    as _i1001;
import 'package:spinfolk/features/settings/domain/prefs_repository.dart'
    as _i753;
import 'package:spinfolk/features/settings/presentation/cubit/settings_cubit.dart'
    as _i611;
import 'package:spinfolk/features/setup/presentation/cubit/setup_cubit.dart'
    as _i351;
import 'package:spinfolk/platform/announcer.dart' as _i385;
import 'package:spinfolk/platform/native_bridge.dart' as _i38;
import 'package:sqflite/sqflite.dart' as _i779;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final coreModule = _$CoreModule();
    final routerModule = _$RouterModule();
    gh.factory<_i351.SetupCubit>(() => _i351.SetupCubit());
    await gh.singletonAsync<_i779.Database>(
      () => coreModule.database,
      preResolve: true,
    );
    await gh.singletonAsync<_i460.SharedPreferencesWithCache>(
      () => coreModule.preferences,
      preResolve: true,
    );
    gh.lazySingleton<_i407.Random>(() => coreModule.random);
    gh.lazySingleton<_i38.NativeBridge>(
      () => _i38.NativeBridge(),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i555.SessionRepository>(
      () => _i818.SessionRepositoryImpl(gh<_i779.Database>()),
    );
    gh.lazySingleton<_i986.SessionBloc>(
      () =>
          _i986.SessionBloc(gh<_i555.SessionRepository>(), gh<_i407.Random>()),
    );
    gh.lazySingleton<_i67.HistoryRepository>(
      () => _i692.HistoryRepositoryImpl(gh<_i779.Database>()),
    );
    gh.lazySingleton<_i753.PrefsRepository>(
      () => _i1001.PrefsRepositoryImpl(gh<_i460.SharedPreferencesWithCache>()),
    );
    gh.lazySingleton<_i583.GoRouter>(
      () => routerModule.router(gh<_i986.SessionBloc>()),
    );
    gh.lazySingleton<_i295.HistoryCubit>(
      () => _i295.HistoryCubit(gh<_i67.HistoryRepository>()),
    );
    gh.lazySingleton<_i611.SettingsCubit>(
      () => _i611.SettingsCubit(
        gh<_i753.PrefsRepository>(),
        gh<_i38.NativeBridge>(),
      ),
    );
    gh.lazySingleton<_i854.AppNavigator>(
      () => _i854.AppNavigator(gh<_i583.GoRouter>()),
    );
    gh.lazySingleton<_i385.Announcer>(
      () => _i385.Announcer(
        gh<_i986.SessionBloc>(),
        gh<_i38.NativeBridge>(),
        gh<_i611.SettingsCubit>(),
      ),
    );
    return this;
  }
}

class _$CoreModule extends _i864.CoreModule {}

class _$RouterModule extends _i1010.RouterModule {}
