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

  test('activity calls send the contract maps', () async {
    native.install();
    expect(
      await bridge.syncActivity({'sessionId': 'x'}),
      ActivityStatus.active,
    );
    await bridge.endActivity('x', 3);
    await bridge.reconcileActivities(null);
    await bridge.linksReady();
    expect(
      [for (final c in native.calls) c.method],
      ['activity.sync', 'activity.end', 'activity.reconcile', 'url.ready'],
    );
    expect(native.calls[1].arguments, {'sessionId': 'x', 'rounds': 3});
    expect(native.calls[2].arguments, {'sessionId': null});
  });

  test('sync status mapping', () async {
    native.install();
    for (final s in ['active', 'disabled', 'error']) {
      native.activityState = s;
      expect((await bridge.syncActivity({})).name, s);
    }
    native.activityState = 'weird';
    expect(await bridge.syncActivity({}), ActivityStatus.error);
  });

  test('activity.sync PlatformException -> error', () async {
    native.install();
    native.failActivitySync = true;
    expect(await bridge.syncActivity({}), ActivityStatus.error);
  });

  test('activity: no handler -> unsupported, never throws', () async {
    expect(await bridge.syncActivity({}), ActivityStatus.unsupported);
    await bridge.endActivity('x', 1);
    await bridge.reconcileActivities('x');
    await bridge.linksReady();
  });

  test('url.open: only valid ids reach the stream', () async {
    native.install();
    final got = <String>[];
    final sub = bridge.sessionLinks.listen(got.add);
    final ok = 'a1' * 16;
    for (final arg in <Object?>[
      {'sessionId': ok},
      {'sessionId': ok.toUpperCase()},
      {'sessionId': 'a' * 31},
      {'sessionId': '../' * 11},
      <String, Object?>{},
      'nope',
    ]) {
      await native.send('url.open', arg);
    }
    await pumpEventQueue();
    await sub.cancel();
    expect(got, [ok]);
  });
}
