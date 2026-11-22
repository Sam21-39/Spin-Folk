import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';

import '../features/game/presentation/pages/end_confirm_page.dart';
import '../features/game/presentation/pages/game_page.dart';
import '../features/game/presentation/pages/round_log_sheet_page.dart';
import '../features/history/presentation/pages/delete_confirm_page.dart';
import '../features/history/presentation/pages/history_detail_page.dart';
import '../features/history/presentation/pages/history_page.dart';
import '../features/history/presentation/pages/summary_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/session/domain/entities/session.dart';
import '../features/session/presentation/bloc/session_bloc.dart';
import '../features/settings/presentation/pages/settings_sheet_page.dart';
import '../features/setup/presentation/pages/add_names_page.dart';
import '../features/setup/presentation/pages/new_game_page.dart';
import 'app_navigator.dart';
import 'bloc_listenable.dart';
import 'tokens.dart';

final _historyPath = RegExp(r'^/history(/clear|/[^/]+(/delete)?)?$');

/// Pure: where a location must go for a session state, or null to stay.
String? sessionRedirect(SessionState state, Uri uri) {
  final path = uri.path;
  final edit = uri.queryParameters['edit'] == '1';
  final history = _historyPath.hasMatch(path);
  final setup = path == '/new' || path == '/names';
  return switch (state) {
    SessionLoading() => null,
    NoSession() ||
    ResumePrompt() => path == '/' || setup || history ? null : '/',
    SessionSummary() => path == '/summary' || history ? null : '/summary',
    SessionActive() =>
      path == '/game' ||
              path == '/game/settings' ||
              path == '/game/log' ||
              path == '/game/end'
          ? null
          : (setup &&
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
  Color barrier, {
  required void Function(AppNavigator) dismiss,
}) => CustomTransitionPage<void>(
  key: s.pageKey,
  opaque: false,
  // Barrier tap goes via the router so the redirect picks the right page.
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
            onTap: () => dismiss(ctx.read<AppNavigator>()),
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

const _confirmBarrier = Color(0x8C040810);

GoRouter buildRouter(SessionBloc bloc) => GoRouter(
  initialLocation: '/',
  refreshListenable: BlocListenable(bloc.stream),
  redirect: (_, state) => sessionRedirect(bloc.state, state.uri),
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const HomePage(),
      routes: [
        GoRoute(
          path: 'new',
          builder: (_, s) => NewGamePage(editing: _editing(s)),
        ),
        GoRoute(
          path: 'names',
          builder: (_, s) => AddNamesPage(editing: _editing(s)),
        ),
        GoRoute(
          path: 'history',
          builder: (_, _) => const HistoryPage(),
          routes: [
            // Declared before :id so 'clear' is not read as an id.
            GoRoute(
              path: 'clear',
              pageBuilder: (_, s) => _overlay(
                s,
                const DeleteConfirmPage(id: null),
                _confirmBarrier,
                dismiss: (n) => n.history(),
              ),
            ),
            GoRoute(
              path: ':id',
              builder: (_, s) => HistoryDetailPage(id: s.pathParameters['id']!),
              routes: [
                GoRoute(
                  path: 'delete',
                  pageBuilder: (_, s) {
                    final id = s.pathParameters['id']!;
                    return _overlay(
                      s,
                      DeleteConfirmPage(id: id),
                      _confirmBarrier,
                      dismiss: (n) => n.historyDetail(id),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    GoRoute(path: '/summary', builder: (_, _) => const SummaryPage()),
    GoRoute(
      path: '/game',
      builder: (_, _) => const GamePage(),
      routes: [
        GoRoute(
          path: 'settings',
          pageBuilder: (_, s) => _overlay(
            s,
            const SettingsSheetPage(),
            Tokens.scrim,
            dismiss: (n) => n.game(),
          ),
        ),
        GoRoute(
          path: 'log',
          pageBuilder: (_, s) => _overlay(
            s,
            const RoundLogSheetPage(),
            Tokens.scrim,
            dismiss: (n) => n.game(),
          ),
        ),
        GoRoute(
          path: 'end',
          pageBuilder: (_, s) => _overlay(
            s,
            const EndConfirmPage(),
            _confirmBarrier,
            dismiss: (n) => n.game(),
          ),
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
