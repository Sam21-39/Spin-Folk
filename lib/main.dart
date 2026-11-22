import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'core/di/injection.dart';
import 'features/history/presentation/cubit/history_cubit.dart';
import 'features/session/presentation/bloc/session_bloc.dart';
import 'platform/announcer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Nunito',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  await bootstrap(configureDependencies);
}

/// Runs [init] (opens the DB); any failure shows a static notice, never a
/// stuck launch screen.
Future<void> bootstrap(Future<void> Function() init) async {
  try {
    await init();
  } catch (_) {
    runApp(const StartupFailureApp());
    return;
  }
  final bloc = getIt<SessionBloc>()..add(const AppStarted());
  // The native launch screen covers this; the router never sees SessionLoading.
  if (bloc.state is SessionLoading) {
    await bloc.stream.firstWhere((s) => s is! SessionLoading);
  }
  getIt<Announcer>().start();
  unawaited(getIt<HistoryCubit>().load());
  runApp(const SpinfolkApp());
}

class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({super.key});

  @override
  Widget build(BuildContext context) => const Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(
      color: Color(0xFF111111),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "Couldn't open your saved games. "
            'Close Spinfolk and open it again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 17),
          ),
        ),
      ),
    ),
  );
}
