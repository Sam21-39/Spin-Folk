import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class AppNavigator {
  AppNavigator(this._router);
  final GoRouter _router;

  void setup({bool editing = false}) =>
      _router.go(editing ? '/new?edit=1' : '/new');
  void names({bool editing = false}) =>
      _router.go(editing ? '/names?edit=1' : '/names');
  void game() => _router.go('/game'); // also closes the sheet and the dialog
  void settings() => _router.go('/game/settings');
  void confirmEnd() => _router.go('/game/end');
}
