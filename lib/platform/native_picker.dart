import 'package:flutter/widgets.dart';

import 'native_island.dart';

class NativePicker extends StatelessWidget {
  const NativePicker({
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final int min, max, value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => NativeIsland(
    viewType: 'spinfolk/picker',
    config: {'min': min, 'max': max, 'value': value},
    onCall: (method, args) {
      if (method != 'changed' || args is! Map) return;
      final v = args['value'];
      if (v is int) onChanged(v);
    },
  );
}
