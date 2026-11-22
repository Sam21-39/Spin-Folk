import 'package:material_ui/material_ui.dart';

import '../../../../app/tokens.dart';
import '../../../../platform/glass_button.dart';
import '../cubit/history_cubit.dart';

class UndoToast extends StatelessWidget {
  const UndoToast({
    required this.count,
    required this.onUndo,
    required this.flat,
    super.key,
  });
  final int count;
  final VoidCallback onUndo;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    // Explicit children: the Undo button stays its own node; the text announces.
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        height: 60,
        padding: const EdgeInsets.only(left: 16, right: 8),
        decoration: ShapeDecoration(
          color: Tokens.bgRaised,
          shape: const StadiumBorder(side: BorderSide(color: Tokens.line)),
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 22,
              child: still
                  ? const CircularProgressIndicator(
                      value: 1,
                      strokeWidth: 2.5,
                      color: Tokens.textPrimary,
                    )
                  : TweenAnimationBuilder<double>(
                      tween: Tween(begin: 1, end: 0),
                      duration: HistoryCubit.undoWindow,
                      builder: (_, v, _) => CircularProgressIndicator(
                        value: v,
                        strokeWidth: 2.5,
                        color: Tokens.textPrimary,
                      ),
                    ),
            ),
            const SizedBox(width: Tokens.s12),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  count == 1 ? 'Game deleted' : '$count games deleted',
                  style: Tokens.headline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            GlassButton(
              label: 'Undo',
              prominent: true,
              flat: flat,
              onPressed: onUndo,
              child: const Text(
                'Undo',
                style: TextStyle(
                  color: Tokens.bgBase,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
