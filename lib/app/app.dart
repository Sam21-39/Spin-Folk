import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/di/injection.dart';
import '../features/session/presentation/bloc/session_bloc.dart';
import '../features/setup/presentation/cubit/setup_cubit.dart';
import 'app_navigator.dart';
import 'tokens.dart';

class SpinfolkApp extends StatelessWidget {
  const SpinfolkApp({super.key});

  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
    providers: [
      RepositoryProvider<AppNavigator>.value(value: getIt<AppNavigator>()),
    ],
    child: MultiBlocProvider(
      providers: [
        BlocProvider<SessionBloc>.value(value: getIt<SessionBloc>()),
        BlocProvider<SetupCubit>(create: (_) => getIt<SetupCubit>()),
      ],
      child: BlocListener<SessionBloc, SessionState>(
        // "Clears N players": old names must not reappear on New Game.
        listenWhen: (a, b) =>
            b is NoSession && (a is SessionActive || a is ResumePrompt),
        listener: (context, _) => context.read<SetupCubit>().reset(),
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
