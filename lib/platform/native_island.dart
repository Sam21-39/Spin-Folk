import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Owns the per-view MethodChannel for one native island instance.
/// Scoped to the island's subtree by RepositoryProvider, so no State class
/// and no app-wide singleton (two action bars can coexist mid-transition).
class NativeViewLink {
  NativeViewLink(this.viewType);
  final String viewType;

  void Function(String method, Object? arguments)? onCall;

  MethodChannel? _channel;
  Map<String, Object?>? _config;
  String? _encoded;

  void attach(int viewId) {
    _channel?.setMethodCallHandler(null);
    final channel = MethodChannel('$viewType/$viewId');
    channel.setMethodCallHandler((call) async {
      // Native state may have diverged; force the next config() to resend as an ack.
      _encoded = null;
      onCall?.call(call.method, call.arguments);
    });
    _channel = channel;
    _send();
  }

  void config(Map<String, Object?> config) {
    // jsonEncode compare: configs are small nested maps and mapEquals is shallow.
    final encoded = jsonEncode(config);
    if (encoded == _encoded) return;
    _encoded = encoded;
    _config = config;
    _send();
  }

  void dispose() {
    _channel?.setMethodCallHandler(null);
    _channel = null;
  }

  Future<void> _send() async {
    final channel = _channel;
    final config = _config;
    if (channel == null || config == null) return;
    try {
      await channel.invokeMethod<void>('config', config);
    } on MissingPluginException catch (e) {
      debugPrint('NativeViewLink config failed: $e');
    } on PlatformException catch (e) {
      debugPrint('NativeViewLink config failed: $e');
    }
  }
}

class NativeIsland extends StatelessWidget {
  const NativeIsland({
    required this.viewType,
    required this.config,
    required this.onCall,
    super.key,
  });

  final String viewType;
  final Map<String, Object?> config;
  final void Function(String method, Object? arguments) onCall;

  @override
  Widget build(BuildContext context) => RepositoryProvider<NativeViewLink>(
    create: (_) => NativeViewLink(viewType),
    dispose: (link) => link.dispose(),
    child: _IslandView(viewType: viewType, config: config, onCall: onCall),
  );
}

class _IslandView extends StatelessWidget {
  const _IslandView({
    required this.viewType,
    required this.config,
    required this.onCall,
  });

  final String viewType;
  final Map<String, Object?> config;
  final void Function(String method, Object? arguments) onCall;

  @override
  Widget build(BuildContext context) {
    final link = context.read<NativeViewLink>();
    // Deliberate side effect in build: this is the sync point from declarative
    // config to the native view, and NativeViewLink.config is idempotent.
    link
      ..onCall = onCall
      ..config(config);
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const SizedBox.expand();
    }
    return UiKitView(
      viewType: viewType,
      creationParams: config,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: link.attach,
      gestureRecognizers: const {
        Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
      },
    );
  }
}
