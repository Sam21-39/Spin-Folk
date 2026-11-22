import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Scaffold;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:spinfolk/app/app.dart';
import 'package:spinfolk/app/app_navigator.dart';
import 'package:spinfolk/app/router.dart';
import 'package:spinfolk/core/di/injection.dart';
import 'package:spinfolk/features/session/domain/entities/session.dart';
import 'package:spinfolk/features/session/presentation/bloc/session_bloc.dart';
import 'package:spinfolk/features/setup/presentation/cubit/setup_cubit.dart';
import 'package:spinfolk/platform/native_action_bar.dart';

import 'fake_session_repository.dart';

/// Registers a SessionBloc on a fake repository, the real router and
/// navigator, then pumps SpinfolkApp. Returns the fake.
Future<FakeSessionRepository> pumpApp(
  WidgetTester tester, {
  Session? stored,
  int seed = 1,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  await tester.pumpWidget(const SizedBox.shrink()); // drop any previous app
  await getIt.reset();
  final repo = FakeSessionRepository()..stored = stored;
  final bloc = SessionBloc(repo, Random(seed));
  getIt
    ..registerSingleton<SessionBloc>(bloc)
    ..registerSingleton<GoRouter>(buildRouter(bloc))
    ..registerSingleton<AppNavigator>(AppNavigator(getIt<GoRouter>()))
    ..registerFactory<SetupCubit>(SetupCubit.new);
  addTearDown(() async {
    await bloc.close();
    await getIt.reset();
  });

  bloc.add(const AppStarted());
  await tester.pump();
  await tester.pumpWidget(const SpinfolkApp());
  await tester.pumpAndSettle();
  return repo;
}

/// Finds the NativeActionBar holding an enabled item [id], calls its onTap
/// (the islands are empty boxes on the test host), then pumps one frame.
Future<void> tapBar(WidgetTester tester, String id) async {
  for (final bar in tester.widgetList<NativeActionBar>(
    find.byType(NativeActionBar),
  )) {
    if (bar.items.any((i) => i.id == id && i.enabled)) {
      bar.onTap(id);
      // Bloc streams deliver on a microtask: one pump to emit, one to build.
      await tester.pump();
      await tester.pump();
      return;
    }
  }
  fail('no enabled action bar item "$id"');
}

T read<T>(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).first).read<T>();
