import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';

import '../features/game/presentation/pages/end_confirm_page.dart';
import '../features/game/presentation/pages/game_page.dart';
import '../features/session/domain/entities/session.dart';
import '../features/session/presentation/bloc/session_bloc.dart';
import '../features/session/presentation/pages/resume_page.dart';
import '../features/settings/presentation/pages/settings_sheet_page.dart';
import '../features/setup/presentation/pages/add_names_page.dart';
import '../features/setup/presentation/pages/new_game_page.dart';
import 'app_navigator.dart';
import 'bloc_listenable.dart';
import 'tokens.dart';

/// Pure: where a location must go for a session state, or null to stay.
String? sessionRedirect(SessionState state, Uri uri) {
  final path = uri.path;
  final edit = uri.queryParameters['edit'] == '1';
  return switch (state) {
    SessionLoading() => null,
    NoSession() => path == '/new' || path == '/names' ? null : '/new',
    ResumePrompt() =>
      path == '/resume' || path == '/game/end' ? null : '/resume',
    SessionActive() =>
      path == '/game' || path == '/game/settings' || path == '/game/end'
          ? null
          : ((path == '/new' || path == '/names') &&
                    edit &&
                    state.session.phase == Phase.ready &&
                    !state.spinning
                ? null
                : '/game'),
  };
}

bool _editing(GoRouterState s) => s.uri.queryParameters['edit'] == '1';

CustomTransitionPage<void> _overlay(
  GoRouterState s,
  Widget child,
  Color barrier,
) => CustomTransitionPage<void>(
  key: s.pageKey,
  opaque: false,
  // Barrier tap goes via go('/game') so the redirect picks the right page.
  barrierDismissible: false,
  barrierLabel: 'Dismiss',
  barrierColor: barrier,
  transitionDuration: Tokens.panelEnter,
  reverseTransitionDuration: Tokens.panelEnter,
  child: Stack(
    children: [
      Positioned.fill(
        child: Builder(
          builder: (ctx) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => ctx.read<AppNavigator>().game(),
          ),
        ),
      ),
      child,
    ],
  ),
  transitionsBuilder: (context, animation, _, child) =>
      MediaQuery.disableAnimationsOf(context)
      ? FadeTransition(opacity: animation, child: child)
      : SlideTransition(
          position: Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
          child: child,
        ),
);

GoRouter buildRouter(SessionBloc bloc) => GoRouter(
  initialLocation: '/new',
  refreshListenable: BlocListenable(bloc.stream),
  redirect: (_, state) => sessionRedirect(bloc.state, state.uri),
  routes: [
    GoRoute(
      path: '/new',
      builder: (_, s) => NewGamePage(editing: _editing(s)),
    ),
    GoRoute(
      path: '/names',
      builder: (_, s) => AddNamesPage(editing: _editing(s)),
    ),
    GoRoute(path: '/resume', builder: (_, _) => const ResumePage()),
    GoRoute(
      path: '/game',
      builder: (_, _) => const GamePage(),
      routes: [
        GoRoute(
          path: 'settings',
          pageBuilder: (_, s) =>
              _overlay(s, const SettingsSheetPage(), Tokens.scrim),
        ),
        GoRoute(
          path: 'end',
          pageBuilder: (_, s) =>
              _overlay(s, const EndConfirmPage(), const Color(0x8C040810)),
        ),
      ],
    ),
  ],
);

@module
abstract class RouterModule {
  @lazySingleton
  GoRouter router(SessionBloc bloc) => buildRouter(bloc);
}
