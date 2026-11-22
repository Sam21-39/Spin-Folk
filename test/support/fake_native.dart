import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mock iOS side of spinfolk/native for host tests.
class FakeNative {
  final List<MethodCall> calls = [];
  bool failSpeak = false;
  String activityState = 'active';
  bool failActivitySync = false;
  Duration activityDelay = Duration.zero;

  /// Holds speech.speak replies until completed.
  Completer<void>? speakGate;
  List<Map<String, String>> voices = [];

  static const _name = 'spinfolk/native';

  void install() => TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel(_name), _handle);

  void uninstall() => TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel(_name), null);

  Future<Object?> _handle(MethodCall call) async {
    calls.add(call);
    switch (call.method) {
      case 'speech.speak':
        final fail = failSpeak;
        await speakGate?.future;
        if (fail) throw PlatformException(code: 'speech');
        return null;
      case 'speech.voices':
        return voices;
      case 'activity.sync':
        if (failActivitySync) throw PlatformException(code: 'activity');
        if (activityDelay > Duration.zero) {
          await Future<void>.delayed(activityDelay);
        }
        return {'state': activityState};
      case 'activity.end':
        return {'ok': true};
      case 'activity.reconcile':
        return {'ended': 0};
      default:
        return null;
    }
  }

  /// Simulates iOS → Dart.
  Future<void> send(String method, Object? arguments) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            _name,
            const StandardMethodCodec().encodeMethodCall(
              MethodCall(method, arguments),
            ),
            (_) {},
          );

  List<MethodCall> named(String method) => [
    for (final c in calls)
      if (c.method == method) c,
  ];
}
