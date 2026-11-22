import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_navigator.dart';
import '../../../../app/ui.dart';
import '../../../session/presentation/bloc/session_bloc.dart';

class EndConfirmPage extends StatelessWidget {
  const EndConfirmPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<SessionBloc>();
    final nav = context.read<AppNavigator>();
    return BlocBuilder<SessionBloc, SessionState>(
      builder: (context, st) {
        if (st is! SessionActive) return const SizedBox.shrink();
        final n = st.session.playerCount;
        final r = st.session.log.length;
        return ConfirmSheet(
          title: 'End this session?',
          body: r == 0
              ? 'No rounds played, so nothing is saved. '
                    'Voice settings stay. Lock Screen activity ends too.'
              : 'Saves $n players and $r ${r == 1 ? 'round' : 'rounds'} '
                    'to History. Voice settings stay. '
                    'Lock Screen activity ends too.',
          confirmLabel: 'End Session',
          failure: st.failure,
          onConfirm: () => bloc.add(const EndConfirmed()),
          onCancel: nav.game,
        );
      },
    );
  }
}
