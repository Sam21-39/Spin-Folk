import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';

import '../dev/glass_proof_page.dart';

@module
abstract class RouterModule {
  @lazySingleton
  GoRouter get router => GoRouter(
    initialLocation: '/new',
    routes: [
      // TEMP(phase-1): proof harness replaces the New Game screen until Phase 2.
      GoRoute(path: '/new', builder: (_, _) => const GlassProofPage()),
    ],
  );
}
