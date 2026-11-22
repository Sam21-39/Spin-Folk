import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/tokens.dart';
import '../../../session/domain/entities/session.dart';
import '../../../session/domain/rules/labels.dart';
import '../../../session/presentation/bloc/session_bloc.dart';
import 'dial_painter.dart';

bool _spinning(SessionState s) => s is SessionActive && s.spinning;

class SpinStage extends StatefulWidget {
  const SpinStage({super.key});

  @override
  State<SpinStage> createState() => _SpinStageState();
}

class _SpinStageState extends State<SpinStage> with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this)
    ..addStatusListener(_onSpinStatus);
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: Tokens.pulse,
  );

  @override
  void initState() {
    super.initState();
    // Mounted mid-spin: progress is unknown, so settle immediately.
    final bloc = context.read<SessionBloc>();
    if (_spinning(bloc.state)) bloc.add(const SpinAnimationFinished());
  }

  void _onSpinStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    HapticFeedback.mediumImpact(); // the only haptic; backgrounding gives none
    context.read<SessionBloc>().add(const SpinAnimationFinished());
  }

  @override
  void dispose() {
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  String _label(SessionActive s) {
    if (s.spinning) return 'Bottle spinning';
    final session = s.session;
    final o = session.outcome;
    if (session.phase == Phase.ready || o == null) {
      return 'Dial, ${session.playerCount} players, ready to spin';
    }
    return 'Taker ${displayLabel(session.players[o.taker])}, '
        'Giver ${displayLabel(session.players[o.giver])}';
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return BlocConsumer<SessionBloc, SessionState>(
      listenWhen: (a, b) => _spinning(a) != _spinning(b),
      listener: (context, s) {
        if (s is SessionActive && s.spinning) {
          _pulse.value = 0;
          _spin.duration = reduce
              ? Tokens.reducedSpin
              : Duration(milliseconds: s.spinPlan!.durationMs);
          _spin.forward(from: 0);
        } else {
          _spin.stop();
          if (!reduce && s is SessionActive && s.session.outcome != null) {
            _pulse.forward(from: 0);
          }
        }
      },
      builder: (context, s) {
        if (s is! SessionActive) return const SizedBox.shrink();
        return Semantics(
          label: _label(s),
          image: true,
          child: ExcludeSemantics(
            child: CustomPaint(
              size: Size.infinite,
              painter: DialPainter(
                n: s.session.playerCount,
                spin: _spin,
                pulse: _pulse,
                orientation: s.orientation,
                plan: s.spinning ? s.spinPlan : null,
                outcome: s.spinning ? null : s.session.outcome,
                reduceMotion: reduce,
              ),
            ),
          ),
        );
      },
    );
  }
}
