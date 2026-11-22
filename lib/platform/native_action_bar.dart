import 'package:flutter/widgets.dart';

import 'native_island.dart';

enum ActionBarStyle { primary, secondary, destructive, choice }

enum ActionBarLayout { stack, row }

class ActionBarItem {
  const ActionBarItem({
    required this.id,
    required this.label,
    this.style = ActionBarStyle.secondary,
    this.enabled = true,
  });

  final String id, label;
  final ActionBarStyle style;
  final bool enabled;
}

class NativeActionBar extends StatelessWidget {
  const NativeActionBar({
    required this.items,
    required this.onTap,
    this.layout = ActionBarLayout.stack,
    super.key,
  });

  final List<ActionBarItem> items;
  final ActionBarLayout layout;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => NativeIsland(
    viewType: 'spinfolk/actionbar',
    config: {
      'items': [
        for (final i in items)
          {
            'id': i.id,
            'label': i.label,
            'style': i.style.name,
            'enabled': i.enabled,
          },
      ],
      'layout': layout.name,
    },
    onCall: (method, args) {
      if (method != 'tap' || args is! Map) return;
      final id = args['id'];
      if (id is String) onTap(id);
    },
  );
}
