// TEMP(phase-1): glass proof harness. Delete in Phase 2.
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'proof_cubit.dart';
import 'test_painter.dart';

class ProofSpin extends StatefulWidget {
  const ProofSpin({super.key});

  @override
  State<ProofSpin> createState() => _ProofSpinState();
}

class _ProofSpinState extends State<ProofSpin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          context.read<ProofCubit>().spinFinished();
        }
      });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocListener<ProofCubit, ProofState>(
    listenWhen: (a, b) => !a.spinning && b.spinning,
    listener: (context, _) {
      _c.duration = MediaQuery.disableAnimationsOf(context)
          ? const Duration(milliseconds: 600)
          : const Duration(seconds: 10);
      _c.forward(from: 0);
    },
    child: CustomPaint(painter: TestPainter(_c), size: Size.infinite),
  );
}
