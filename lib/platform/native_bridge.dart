import 'dart:async';

import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

import '../features/settings/domain/prefs.dart';

enum SpeechEvent { done, cancelled, error } // .name is the wire value

enum ActivityStatus { active, disabled, unsupported, error }

final _sessionId = RegExp(r'^[0-9a-f]{32}$');

/// Dart side of the shared spinfolk/native channel. Phase 4 adds methods.
@lazySingleton
class NativeBridge {
  NativeBridge() {
    _channel.setMethodCallHandler(_onCall);
  }

  static const MethodChannel _channel = MethodChannel('spinfolk/native');

  final _events = StreamController<SpeechEvent>.broadcast();

  final _links = StreamController<String>.broadcast();

  Stream<SpeechEvent> get speechEvents => _events.stream;

  /// Validated session ids from `spinfolk://session/<id>` links.
  Stream<String> get sessionLinks => _links.stream;

  Future<void> _onCall(MethodCall call) async {
    final a = call.arguments;
    if (a is! Map) return;
    switch (call.method) {
      case 'speech.event':
        for (final e in SpeechEvent.values) {
          if (e.name == a['state']) _events.add(e);
        }
      case 'url.open':
        final id = a['sessionId'];
        if (id is String && _sessionId.hasMatch(id)) _links.add(id);
    }
  }

  /// true when iOS accepted the line. Never throws.
  Future<bool> speak(
    String text, {
    String? voiceId,
    required double rate,
  }) async {
    try {
      await _channel.invokeMethod<void>('speech.speak', {
        'text': text,
        'voiceId': voiceId,
        'rate': rate,
      });
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> stopSpeech() async {
    try {
      await _channel.invokeMethod<void>('speech.stop');
    } on PlatformException {
      // nothing to stop
    } on MissingPluginException {
      // nothing to stop
    }
  }

  /// Installed voices whose language starts with [language]. [] on any error.
  Future<List<Voice>> voices(String language) async {
    try {
      final raw = await _channel.invokeListMethod<Object?>('speech.voices', {
        'language': language,
      });
      return [
        for (final m in raw ?? const <Object?>[])
          if (m is Map &&
              _str(m['id']) &&
              _str(m['name']) &&
              _str(m['language']))
            Voice(
              id: m['id'] as String,
              name: m['name'] as String,
              language: m['language'] as String,
              quality: switch (m['quality']) {
                'enhanced' => VoiceQuality.enhanced,
                'premium' => VoiceQuality.premium,
                _ => VoiceQuality.standard,
              },
            ),
      ];
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  /// Tells iOS the link handler is set; a held cold-start link is delivered.
  Future<void> linksReady() => _fire('url.ready');

  /// Never throws.
  Future<ActivityStatus> syncActivity(Map<String, Object?> payload) async {
    try {
      final r = await _channel.invokeMapMethod<String, Object?>(
        'activity.sync',
        payload,
      );
      for (final s in ActivityStatus.values) {
        if (s.name == r?['state']) return s;
      }
      return ActivityStatus.error;
    } on MissingPluginException {
      return ActivityStatus.unsupported;
    } on PlatformException {
      return ActivityStatus.error;
    }
  }

  Future<void> endActivity(String sessionId, int rounds) =>
      _fire('activity.end', {'sessionId': sessionId, 'rounds': rounds});

  /// Ends every activity except [keepSessionId]'s (all when null).
  Future<void> reconcileActivities(String? keepSessionId) =>
      _fire('activity.reconcile', {'sessionId': keepSessionId});

  Future<void> _fire(String method, [Object? args]) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on PlatformException {
      // best effort
    } on MissingPluginException {
      // best effort
    }
  }

  static bool _str(Object? v) => v is String && v.isNotEmpty;

  @disposeMethod
  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _events.close();
    await _links.close();
  }
}
