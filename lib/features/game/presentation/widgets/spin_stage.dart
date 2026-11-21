import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/tokens.dart';
import '../../../session/domain/entities/session.dart';
import '../../../session/domain/rules/labels.dart';
import '../../../session/presentation/bloc/session_bloc.dart';
import 'dial_painter.dart';
import 'flick.dart';

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

  // Finger offset of the bottle; visual only, never read into an event (D11).
  late final AnimationController _drag = AnimationController.unbounded(
    vsync: this,
  );

  /// Pointer vector from the centre while a drag is active.
  Offset? _grab;

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
    _drag.dispose();
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

  Offset _fromCentre(Offset p) => p - (context.size!.center(Offset.zero));

  void _snapBack() {
    _grab = null;
    _drag.animateTo(0, duration: Tokens.snapBack, curve: Curves.easeOut);
  }

  void _onPanStart(DragStartDetails d) {
    final v = _fromCentre(d.localPosition);
    // Only the bottle's sweep grabs it.
    if (v.distance <= 8 || v.distance > context.size!.shortestSide / 2 * 0.66) {
      return;
    }
    _grab = v;
    _drag.stop();
    HapticFeedback.lightImpact();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final g = _grab;
    if (g == null) return;
    final v = _fromCentre(d.localPosition);
    _drag.value += angleDelta(g, v);
    _grab = v;
  }

  void _onPanEnd(DragEndDetails d) {
    final g = _grab;
    if (g == null) return;
    _grab = null;
    final w = angularVelocity(g, d.velocity.pixelsPerSecond);
    if (w.abs() >= Tokens.flickMinSpeed) {
      _drag.value = wrapPi(_drag.value);
      final bloc = context.read<SessionBloc>()..add(const SpinRequested());
      // Bloc ignored the flick (no spin started): the listener never fires.
      Future(() {
        if (mounted && !_spinning(bloc.state)) _snapBack();
      });
    } else {
      _snapBack();
    }
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
          _drag.value = 0;
          if (!reduce && s is SessionActive && s.session.outcome != null) {
            _pulse.forward(from: 0);
          }
        }
      },
      builder: (context, s) {
        if (s is! SessionActive) return const SizedBox.shrink();
        final flick = !s.spinning && s.session.phase == Phase.ready;
        return Semantics(
          label: _label(s),
          hint: flick ? 'Flick to spin, or use the Spin button' : null,
          image: true,
          child: GestureDetector(
            onPanStart: flick ? _onPanStart : null,
            onPanUpdate: flick ? _onPanUpdate : null,
            onPanEnd: flick ? _onPanEnd : null,
            onPanCancel: flick ? _snapBack : null,
            child: ExcludeSemantics(
              child: CustomPaint(
                size: Size.infinite,
                painter: DialPainter(
                  n: s.session.playerCount,
                  spin: _spin,
                  pulse: _pulse,
                  drag: _drag,
                  orientation: s.orientation,
                  plan: s.spinning ? s.spinPlan : null,
                  outcome: s.spinning ? null : s.session.outcome,
                  reduceMotion: reduce,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
