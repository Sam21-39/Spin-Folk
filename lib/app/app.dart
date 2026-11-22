import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/di/injection.dart';
import '../features/history/presentation/cubit/history_cubit.dart';
import '../features/session/presentation/bloc/session_bloc.dart';
import '../features/settings/presentation/cubit/settings_cubit.dart';
import '../features/setup/presentation/cubit/setup_cubit.dart';
import '../platform/announcer.dart';
import '../platform/live_activity_sync.dart';
import 'app_navigator.dart';
import 'tokens.dart';

class SpinfolkApp extends StatelessWidget {
  const SpinfolkApp({super.key});

  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
    providers: [
      RepositoryProvider<AppNavigator>.value(value: getIt<AppNavigator>()),
      RepositoryProvider<AppLifecycleListener>(
        lazy: false,
        // onHide, not onInactive: Control Centre must not cut a spin short.
        create: (_) => AppLifecycleListener(
          onHide: () {
            getIt<SessionBloc>().add(const AppBackgrounded());
            unawaited(getIt<HistoryCubit>().purgeNow());
          },
          onResume: () => getIt<LiveActivitySync>().foreground(),
        ),
        dispose: (listener) => listener.dispose(),
      ),
    ],
    child: MultiBlocProvider(
      providers: [
        BlocProvider<SessionBloc>.value(value: getIt<SessionBloc>()),
        BlocProvider<HistoryCubit>.value(value: getIt<HistoryCubit>()),
        BlocProvider<SettingsCubit>.value(value: getIt<SettingsCubit>()),
        BlocProvider<Announcer>.value(value: getIt<Announcer>()),
        BlocProvider<SetupCubit>(create: (_) => getIt<SetupCubit>()),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<SessionBloc, SessionState>(
            // "Clears N players": old names must not reappear on New Game.
            listenWhen: (a, b) =>
                a is SessionActive && (b is NoSession || b is SessionSummary),
            listener: (context, _) => context.read<SetupCubit>().reset(),
          ),
          BlocListener<SessionBloc, SessionState>(
            // A session may have archived a game.
            listenWhen: (a, b) => a.runtimeType != b.runtimeType,
            listener: (context, _) => context.read<HistoryCubit>().load(),
          ),
        ],
        child: MaterialApp.router(
          title: 'Spinfolk',
          debugShowCheckedModeBanner: false, // clean evidence screenshots
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: Tokens.bgBase,
          ),
          routerConfig: getIt<GoRouter>(),
        ),
      ),
    ),
  );
}
