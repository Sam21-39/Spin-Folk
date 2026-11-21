import 'dart:async';

import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

import '../features/settings/domain/prefs.dart';

enum SpeechEvent { done, cancelled, error } // .name is the wire value

/// Dart side of the shared spinfolk/native channel. Phase 4 adds methods.
@lazySingleton
class NativeBridge {
  NativeBridge() {
    _channel.setMethodCallHandler(_onCall);
  }

  static const MethodChannel _channel = MethodChannel('spinfolk/native');

  final _events = StreamController<SpeechEvent>.broadcast();

  Stream<SpeechEvent> get speechEvents => _events.stream;

  Future<void> _onCall(MethodCall call) async {
    if (call.method != 'speech.event') return;
    final a = call.arguments;
    if (a is! Map) return;
    for (final e in SpeechEvent.values) {
      if (e.name == a['state']) _events.add(e);
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

  static bool _str(Object? v) => v is String && v.isNotEmpty;

  @disposeMethod
  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _events.close();
  }
}
