import 'package:flutter/widgets.dart';

import 'tokens.dart';

class PageFrame extends StatelessWidget {
  const PageFrame({required this.child, this.inset = true, super.key});
  final Widget child;

  /// false: the child pads itself (lets a scroll view span the full width).
  final bool inset;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Tokens.maxContentWidth),
        child: inset
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: Tokens.margin),
                child: child,
              )
            : child,
      ),
    ),
  );
}

class NoticeBanner extends StatelessWidget {
  const NoticeBanner(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: Tokens.bgRaised,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Tokens.textSecondary, fontSize: 13),
      ),
    ),
  );
}

/// Multiplies island heights so native labels (clamped at .accessibility2)
/// are not clipped.
double barScale(BuildContext context) =>
    (MediaQuery.textScalerOf(context).scale(17) / 17).clamp(1.0, 1.5);

/// For the footnotes that share a fixed-height slot with an island.
TextScaler besideIsland(BuildContext context) =>
    MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.5);
