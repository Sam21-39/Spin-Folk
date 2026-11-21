import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:spinfolk/core/failure.dart';
import 'package:spinfolk/features/settings/domain/prefs.dart';
import 'package:spinfolk/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:spinfolk/platform/native_bridge.dart';

import 'support/fake_native.dart';
import 'support/fake_prefs_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakePrefsRepository repo;
  late FakeNative native;
  late NativeBridge bridge;
  late SettingsCubit cubit;

  setUp(() {
    repo = FakePrefsRepository()..stored = const Prefs(voiceId: 'v1');
    native = FakeNative()..install();
    bridge = NativeBridge();
    cubit = SettingsCubit(repo, bridge);
  });
  tearDown(() async {
    await cubit.close();
    native.uninstall();
    await bridge.dispose();
  });

  test('initial state is stored prefs', () {
    expect(cubit.state.prefs, const Prefs(voiceId: 'v1'));
  });

  test('announceToggled saves', () async {
    await cubit.announceToggled(false);
    expect(cubit.state.prefs.announce, isFalse);
    expect(repo.saved.last.announce, isFalse);
  });

  test('rate: tick clamps, commit saves once', () async {
    cubit.rateChanged(0.9);
    expect(cubit.state.prefs.rate, 0.65);
    expect(repo.saved, isEmpty);
    await cubit.rateCommitted();
    expect(repo.saved, hasLength(1));
  });

  test('voice select saves and closes list; null clears', () async {
    cubit.voiceRowTapped();
    expect(cubit.state.voiceListOpen, isTrue);
    await cubit.voiceSelected('x');
    expect(cubit.state.voiceListOpen, isFalse);
    expect(repo.saved.last.voiceId, 'x');
    await cubit.voiceSelected(null);
    expect(repo.saved.last.voiceId, isNull);
    cubit
      ..voiceRowTapped()
      ..voiceRowTapped();
    expect(cubit.state.voiceListOpen, isFalse);
  });

  test('failed save keeps value, sets failure, next save clears it', () async {
    repo.failWrites = true;
    await cubit.announceToggled(false);
    expect(cubit.state.prefs.announce, isFalse);
    expect(cubit.state.failure, isA<StorageFailure>());
    repo.failWrites = false;
    await cubit.announceToggled(true);
    expect(cubit.state.failure, isNull);
  });

  test('late failed save does not revert a newer value', () async {
    final gate = repo.gate = Completer<void>();
    repo.failWrites = true;
    final a = cubit.announceToggled(false);
    repo
      ..gate = null
      ..failWrites = false;
    await cubit.voiceSelected('v2');
    gate.complete();
    await a;
    expect(cubit.state.prefs, const Prefs(voiceId: 'v2', announce: false));
    expect(cubit.state.failure, isA<StorageFailure>());
  });

  test('opened fills sorted voices, closes list; voiceLabel', () async {
    native.voices = [
      {'id': 'v1', 'name': 'Zed', 'language': 'en', 'quality': 'default'},
      {'id': 'v2', 'name': 'Amy', 'language': 'en', 'quality': 'premium'},
    ];
    cubit.voiceRowTapped();
    await cubit.opened();
    expect(native.named('speech.voices').single.arguments, {'language': 'en'});
    expect(cubit.state.voices.map((v) => v.id), ['v2', 'v1']);
    expect(cubit.state.voiceListOpen, isFalse);
    expect(cubit.state.voiceLabel, 'Zed');
    await cubit.voiceSelected('gone');
    expect(cubit.state.voiceLabel, 'Default');
    await cubit.voiceSelected(null);
    expect(cubit.state.voiceLabel, 'Default');
  });
}
