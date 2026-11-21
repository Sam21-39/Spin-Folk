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
import 'package:spinfolk/features/history/domain/history_repository.dart';
import 'package:spinfolk/features/history/presentation/cubit/history_cubit.dart';
import 'package:spinfolk/features/session/domain/entities/game_record.dart';
import 'package:spinfolk/features/session/domain/entities/session.dart';
import 'package:spinfolk/features/session/presentation/bloc/session_bloc.dart';
import 'package:spinfolk/features/settings/domain/prefs.dart';
import 'package:spinfolk/features/settings/domain/prefs_repository.dart';
import 'package:spinfolk/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:spinfolk/features/setup/presentation/cubit/setup_cubit.dart';
import 'package:spinfolk/platform/announcer.dart';
import 'package:spinfolk/platform/live_activity_sync.dart';
import 'package:spinfolk/platform/native_bridge.dart';
import 'package:spinfolk/platform/native_action_bar.dart';

import 'fake_history_repository.dart';
import 'fake_native.dart';
import 'fake_prefs_repository.dart';
import 'fake_session_repository.dart';

/// The fakes of the latest pumpApp, for assertions.
late FakeNative native;
late FakePrefsRepository prefsRepo;

/// Registers a SessionBloc on a fake repository, the real router and
/// navigator, then pumps SpinfolkApp. Returns the fake.
Future<FakeSessionRepository> pumpApp(
  WidgetTester tester, {
  Session? stored,
  int seed = 1,
  Size size = const Size(390, 844),
  double textScale = 1,
  List<GameRecord> history = const [],
  Prefs prefs = const Prefs(),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  await tester.pumpWidget(const SizedBox.shrink()); // drop any previous app
  await getIt.reset();
  final historyRepo = FakeHistoryRepository(history);
  final repo = FakeSessionRepository(historyRepo)..stored = stored;
  final bloc = SessionBloc(repo, Random(seed));
  final cubit = HistoryCubit(historyRepo);
  // Without the mock every reveal would show the voice notice.
  native = FakeNative()..install();
  prefsRepo = FakePrefsRepository()..stored = prefs;
  final bridge = NativeBridge();
  final settings = SettingsCubit(prefsRepo, bridge);
  final announcer = Announcer(bloc, bridge, settings)..start();
  final activity = LiveActivitySync(bloc, bridge, settings);
  getIt
    ..registerSingleton<HistoryRepository>(historyRepo)
    ..registerSingleton<HistoryCubit>(cubit)
    ..registerSingleton<SessionBloc>(bloc)
    ..registerSingleton<PrefsRepository>(prefsRepo)
    ..registerSingleton<NativeBridge>(bridge)
    ..registerSingleton<SettingsCubit>(settings)
    ..registerSingleton<Announcer>(announcer)
    ..registerSingleton<LiveActivitySync>(activity)
    ..registerSingleton<GoRouter>(buildRouter(bloc))
    ..registerSingleton<AppNavigator>(AppNavigator(getIt<GoRouter>()))
    ..registerFactory<SetupCubit>(SetupCubit.new);
  addTearDown(() async {
    await activity.dispose();
    await announcer.close();
    await settings.close();
    await bridge.dispose();
    native.uninstall();
    await bloc.close();
    await cubit.close();
    await getIt.reset();
  });

  bloc.add(const AppStarted());
  await cubit.load();
  await tester.pump();
  activity.start(); // as main does, after the first non-loading state
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

FakeHistoryRepository historyRepo() =>
    getIt<HistoryRepository>() as FakeHistoryRepository;

/// Taps a button or link by its semantics label (GlassButton and TextLink
/// render their flat path on the test host), then pumps two frames.
Future<void> tapLabel(WidgetTester tester, String label) async {
  final h = tester.ensureSemantics();
  await tester.tap(find.bySemanticsLabel(label));
  h.dispose();
  await tester.pump();
  await tester.pump();
}
