import 'package:adaptive_platform_ui/adaptive_platform_ui.dart'
    show AdaptiveSlider, AdaptiveSwitch;
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// Native switch: AdaptiveSwitch on iOS (platform view on 26+), Material
/// elsewhere (the adaptive fallback needs flutter's own Material ancestor).
class NativeSwitch extends StatelessWidget {
  const NativeSwitch({
    required this.value,
    required this.onChanged,
    this.activeColor,
    super.key,
  });
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) =>
      defaultTargetPlatform == TargetPlatform.iOS
      ? AdaptiveSwitch(
          value: value,
          onChanged: onChanged,
          activeColor: activeColor,
        )
      : Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: activeColor,
        );
}

/// Native slider; same split as [NativeSwitch].
class NativeSlider extends StatelessWidget {
  const NativeSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
    this.activeColor,
    super.key,
  });
  final double value, min, max;
  final ValueChanged<double> onChanged, onChangeEnd;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) =>
      defaultTargetPlatform == TargetPlatform.iOS
      ? AdaptiveSlider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
          activeColor: activeColor,
        )
      : Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
          activeColor: activeColor,
        );
}
