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
import 'package:spinfolk/app/router.dart' as _i1010;
import 'package:spinfolk/core/di/injection.dart' as _i864;
import 'package:spinfolk/features/setup/presentation/cubit/setup_cubit.dart'
    as _i351;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final routerModule = _$RouterModule();
    final coreModule = _$CoreModule();
    gh.factory<_i351.SetupCubit>(() => _i351.SetupCubit());
    gh.lazySingleton<_i583.GoRouter>(() => routerModule.router);
    gh.lazySingleton<_i407.Random>(() => coreModule.random);
    return this;
  }
}

class _$RouterModule extends _i1010.RouterModule {}

class _$CoreModule extends _i864.CoreModule {}
