import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spinfolk/platform/native_island.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('spinfolk/picker/7');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> incoming(String method, Object? args) =>
      messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
        (_) {},
      );

  test('link config/attach/dispose protocol', () async {
    final received = <String>[];
    final link = NativeViewLink('spinfolk/picker')
      ..onCall = (m, a) => received.add('$m:$a');
    final a = <String, Object?>{'value': 1};
    final b = <String, Object?>{'value': 2};

    link.config(a);
    await Future<void>.delayed(Duration.zero);
    expect(calls, isEmpty);

    link.attach(7);
    await Future<void>.delayed(Duration.zero);
    expect(calls.map((c) => c.arguments), [a]);

    link.config({'value': 1});
    await Future<void>.delayed(Duration.zero);
    expect(calls, hasLength(1));

    link.config(b);
    await Future<void>.delayed(Duration.zero);
    expect(calls.map((c) => c.arguments), [a, b]);

    await incoming('changed', {'value': 9});
    expect(received, ['changed:{value: 9}']);

    link.dispose();
    link.config({'value': 3});
    await Future<void>.delayed(Duration.zero);
    expect(calls, hasLength(2));
  });

  test('dispose and re-attach drop old channel handler', () async {
    final received = <String>[];
    final link = NativeViewLink('spinfolk/picker')
      ..onCall = (m, a) => received.add(m);

    link.attach(7);
    link.attach(8);
    await incoming('changed', {'value': 1});
    expect(received, isEmpty);

    link.attach(7);
    await incoming('changed', {'value': 2});
    expect(received, ['changed']);

    link.dispose();
    await incoming('changed', {'value': 3});
    expect(received, ['changed']);
  });

  test('incoming call forces identical config to resend', () async {
    final link = NativeViewLink('spinfolk/picker')..onCall = (m, a) {};
    link.config({'value': 8});
    link.attach(7);
    await Future<void>.delayed(Duration.zero);
    expect(calls, hasLength(1));

    link.config({'value': 8});
    await Future<void>.delayed(Duration.zero);
    expect(calls, hasLength(1));

    await incoming('changed', {'value': 9});
    link.config({'value': 8});
    await Future<void>.delayed(Duration.zero);
    expect(calls, hasLength(2));
  });
}
