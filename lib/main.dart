import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'core/di/injection.dart';
import 'features/history/presentation/cubit/history_cubit.dart';
import 'features/session/presentation/bloc/session_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Nunito',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  await configureDependencies();
  final bloc = getIt<SessionBloc>()..add(const AppStarted());
  // The native launch screen covers this; the router never sees SessionLoading.
  if (bloc.state is SessionLoading) {
    await bloc.stream.firstWhere((s) => s is! SessionLoading);
  }
  unawaited(getIt<HistoryCubit>().load());
  runApp(const SpinfolkApp());
}
