import 'package:adaptive_platform_ui/adaptive_platform_ui.dart'
    show IOS26Button, IOS26ButtonStyle, SFSymbol;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../app/tokens.dart';

/// Small native glass chrome button (pill, icon button, sheet Done, Undo).
/// Liquid Glass on iOS 26+, system material on iOS 17–25 (IOS26Button's own
/// native fallback). Flat surface off iOS and while [flat].
class GlassButton extends StatelessWidget {
  const GlassButton({
    required this.label, // VoiceOver label, always required
    required this.onPressed,
    required this.child, // Flutter-drawn content; gives the width
    this.symbol, // SF Symbol; when set, [child] is only the flat-path glyph
    this.height = Tokens.touch,
    this.prominent = false, // white capsule; caller draws navy content
    this.flat = false, // true while another route covers the page
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget child;
  final String? symbol;
  final double height;
  final bool prominent, flat;

  @override
  Widget build(BuildContext context) {
    final native = defaultTargetPlatform == TargetPlatform.iOS && !flat;
    final sym = symbol;
    return Semantics(
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: !native
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPressed,
              child: Container(
                height: height,
                width: sym != null ? height : null,
                padding: sym != null
                    ? null
                    : const EdgeInsets.symmetric(horizontal: Tokens.s16),
                decoration: ShapeDecoration(
                  color: prominent ? const Color(0xEBFFFFFF) : Tokens.bgRaised,
                  shape: const StadiumBorder(
                    side: BorderSide(color: Tokens.line),
                  ),
                ),
                child: Center(widthFactor: 1, child: child),
              ),
            )
          : sym != null
          ? SizedBox.square(
              dimension: height,
              child: IOS26Button.sfSymbol(
                onPressed: onPressed,
                sfSymbol: SFSymbol(sym, size: 18, color: Tokens.textPrimary),
                style: IOS26ButtonStyle.glass,
                useSmoothRectangleBorder: false,
              ),
            )
          : SizedBox(
              height: height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IOS26Button(
                      onPressed: onPressed,
                      label: '',
                      style: prominent
                          ? IOS26ButtonStyle.prominentGlass
                          : IOS26ButtonStyle.glass,
                      color: prominent ? const Color(0xFFFFFFFF) : null,
                      useSmoothRectangleBorder: false,
                    ),
                  ),
                  IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Tokens.s16,
                      ),
                      child: Center(widthFactor: 1, child: child),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
