import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/failure.dart';
import '../platform/glass_button.dart';
import '../platform/native_action_bar.dart';
import 'tokens.dart';

class PageFrame extends StatelessWidget {
  const PageFrame({required this.child, this.inset = true, super.key});
  final Widget child;

  /// false: the child pads itself (lets a scroll view span the full width).
  final bool inset;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Align(
      alignment: Alignment.topCenter,
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

/// Only the top route shows native views: [covered] is true while another
/// route (sheet, confirm) sits above [path].
class TopRoute extends StatelessWidget {
  const TopRoute({required this.path, required this.builder, super.key});
  final String path;
  final Widget Function(BuildContext context, bool covered) builder;

  @override
  Widget build(BuildContext context) {
    final delegate = GoRouter.of(context).routerDelegate;
    return ListenableBuilder(
      listenable: delegate,
      builder: (context, _) =>
          builder(context, delegate.currentConfiguration.uri.path != path),
    );
  }
}

/// Round log and Session sheets: detents 0.55 / 0.93, drag below 0.25 closes.
class SheetFrame extends StatelessWidget {
  const SheetFrame({
    required this.title,
    required this.onDone,
    required this.slivers,
    this.subtitle,
    super.key,
  });
  final String title;
  final String? subtitle;
  final VoidCallback onDone;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Tokens.maxContentWidth),
      child: NotificationListener<DraggableScrollableNotification>(
        onNotification: (n) {
          if (n.extent <= n.minExtent + 0.01) onDone();
          return false;
        },
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.25,
          maxChildSize: 0.93,
          snap: true,
          snapSizes: const [0.55],
          builder: (context, controller) => Material(
            color: Tokens.bgSheet,
            clipBehavior: Clip.antiAlias,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
              side: BorderSide(color: Tokens.line),
            ),
            child: SafeArea(
              top: false,
              child: CustomScrollView(
                controller: controller,
                slivers: [
                  PinnedHeaderSliver(child: _header(context)),
                  ...slivers,
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _header(BuildContext context) => Container(
    color: Tokens.bgSheet,
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 5,
          decoration: BoxDecoration(
            color: Tokens.dot,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: Tokens.s8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: Tokens.title2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textScaler: besideIsland(context),
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: Tokens.textSecondary,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textScaler: besideIsland(context),
                    ),
                ],
              ),
            ),
            const SizedBox(width: Tokens.s12),
            GlassButton(
              label: 'Done',
              height: 36,
              onPressed: onDone,
              child: const Text(
                'Done',
                style: TextStyle(
                  color: Tokens.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Confirm layout shared by End, Delete and Clear all. Bar ids: confirm, cancel.
class ConfirmSheet extends StatelessWidget {
  const ConfirmSheet({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.onConfirm,
    required this.onCancel,
    this.failure,
    super.key,
  });
  final String title, body, confirmLabel;
  final VoidCallback onConfirm, onCancel;
  final Failure? failure;

  @override
  Widget build(BuildContext context) {
    final sc = barScale(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.s8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Tokens.maxContentWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Semantics(
                          namesRoute: true,
                          explicitChildNodes: true,
                          child: Material(
                            color: Tokens.bgRaised,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                              side: const BorderSide(color: Tokens.line),
                            ),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 18,
                                horizontal: 20,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    title,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Tokens.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: Tokens.s4),
                                  Text(
                                    body,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Tokens.textSecondary,
                                      fontSize: 13,
                                      height: 18 / 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (failure != null)
                          Padding(
                            padding: const EdgeInsets.only(top: Tokens.s8),
                            child: NoticeBanner(failure!.message),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Tokens.s8),
                SizedBox(
                  height:
                      (Tokens.barSecondary +
                          Tokens.barGap +
                          Tokens.barSecondary) *
                      sc,
                  child: NativeActionBar(
                    items: [
                      ActionBarItem(
                        id: 'confirm',
                        label: confirmLabel,
                        style: ActionBarStyle.destructive,
                      ),
                      const ActionBarItem(id: 'cancel', label: 'Cancel'),
                    ],
                    onTap: (id) => switch (id) {
                      'confirm' => onConfirm(),
                      'cancel' => onCancel(),
                      _ => null,
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Teal 17-pt tappable text, 44-pt minimum hit box.
class TextLink extends StatelessWidget {
  const TextLink(
    this.label, {
    required this.onTap,
    this.leading = false,
    this.color = Tokens.taker,
    super.key,
  });
  final String label;
  final VoidCallback onTap;

  /// Leading chevron ("‹ Home").
  final bool leading;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    onTap: onTap,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: Tokens.touch,
          minWidth: Tokens.touch,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading) Icon(Icons.chevron_left, color: color, size: 24),
            Flexible(
              child: Text(
                label,
                style: TextStyle(color: color, fontSize: 17),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: besideIsland(context),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
