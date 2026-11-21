import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/di/injection.dart';
import '../features/setup/presentation/cubit/setup_cubit.dart';
import 'tokens.dart';

class SpinfolkApp extends StatelessWidget {
  const SpinfolkApp({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => getIt<SetupCubit>(),
    child: MaterialApp.router(
      title: 'Spinfolk',
      debugShowCheckedModeBanner: false, // clean evidence screenshots
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Tokens.bgBase,
      ),
      routerConfig: getIt<GoRouter>(),
    ),
  );
}
