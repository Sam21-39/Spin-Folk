import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spinfolk/features/settings/domain/prefs.dart';
import 'package:spinfolk/platform/native_bridge.dart';

import 'support/fake_native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeNative native;
  late NativeBridge bridge;

  setUp(() {
    native = FakeNative();
    bridge = NativeBridge();
  });
  tearDown(() async {
    native.uninstall();
    await bridge.dispose();
  });

  test('speak sends the contract map', () async {
    native.install();
    expect(await bridge.speak('hi', voiceId: 'v', rate: 0.6), isTrue);
    expect(native.calls.single.method, 'speech.speak');
    expect(native.calls.single.arguments, {
      'text': 'hi',
      'voiceId': 'v',
      'rate': 0.6,
    });
  });

  test('speak false on PlatformException and MissingPlugin', () async {
    native
      ..install()
      ..failSpeak = true;
    expect(await bridge.speak('hi', rate: 0.5), isFalse);
    native.uninstall();
    expect(await bridge.speak('hi', rate: 0.5), isFalse);
    await bridge.stopSpeech(); // no handler: must not throw
  });

  test('voices: query, mapping, malformed dropped', () async {
    native
      ..install()
      ..voices = [
        {'id': 'a', 'name': 'A', 'language': 'en-US', 'quality': 'premium'},
        {'id': 'b', 'name': 'B', 'language': 'en-GB', 'quality': 'enhanced'},
        {'id': 'c', 'name': 'C', 'language': 'en-AU', 'quality': 'default'},
        {'name': 'no id', 'language': 'en'},
      ];
    final v = await bridge.voices('en');
    expect(native.calls.single.arguments, {'language': 'en'});
    expect(v.map((x) => x.quality), [
      VoiceQuality.premium,
      VoiceQuality.enhanced,
      VoiceQuality.standard,
    ]);
    expect(v.map((x) => x.id), ['a', 'b', 'c']);
  });

  test('voices: non-map entry dropped, error gives []', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('spinfolk/native'),
          (_) async => [
            'junk',
            {'id': 'a', 'name': 'A', 'language': 'en'},
          ],
        );
    expect((await bridge.voices('en')).map((v) => v.id), ['a']);
    native.uninstall();
    expect(await bridge.voices('en'), isEmpty);
  });

  test('speech.event in order; bogus input ignored', () async {
    final got = <SpeechEvent>[];
    final sub = bridge.speechEvents.listen(got.add);
    for (final s in ['done', 'cancelled', 'error']) {
      await native.send('speech.event', {'state': s});
    }
    await native.send('speech.event', {'state': 'bogus'});
    await native.send('speech.event', 'nope');
    await native.send('other', {'state': 'done'});
    await pumpEventQueue();
    expect(got, [SpeechEvent.done, SpeechEvent.cancelled, SpeechEvent.error]);
    await sub.cancel();
  });
}
