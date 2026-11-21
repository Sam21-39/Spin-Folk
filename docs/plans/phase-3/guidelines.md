# Spinfolk — Phase 3: Implementation Guidelines

Read `prd.md` (this folder), `docs/spec-v2.md`, `docs/plans/phase-2/guidelines.md` §0, and the Phase 2b plan and report first. The spec's architecture is fixed. This file gives order, exact paths, names, shapes and verify commands. Decision ids (D1…) refer to `prd.md` §5.

## 0. Ground rules and reconcile step

- All earlier ground rules apply: every command through `fvm`, run from `/Users/sp/Dev/Games/Spin-Folk`; no `setState`; no `showDialog` / `showModalBottomSheet` / `SnackBar` / `BackdropFilter`; Material import is `package:material_ui/material_ui.dart`; blocs and cubits never see `BuildContext` and never navigate; widget callbacks only forward intent; navigation only through `AppNavigator`.
- **No new dependencies. No Podfile. No `Info.plist` change. No schema change.**
- The only `StatefulWidget` stays `spin_stage.dart` (plus whatever Phase 2b allow-listed in `tool/check_rules.sh`).
- Phase 4 items are not created, not registered, not shown disabled: no `activity.*`, no `url.*`, no `LiveActivitySync`, no Live Activity line in the sheet.
- **No simulator, no Maestro in this phase** (owner decision). Verification = the static block in §12. Device checks P3-D1…D7 are written as flows and reported **NOT VERIFIED**.
- Evidence files (`docs/plans/*/evidence/`) are git-ignored. Never `git add -f` them, never mention committing them.
- Report honestly; paste real output.
- Git: branch `phase-3` from the tip of `phase-2b`. Commit only when the orchestrator or owner says so; never push.

Start condition — before anything else:
```sh
git switch phase-2b && git status --short          # must be clean
fvm dart run build_runner build --delete-conflicting-outputs
fvm dart format --set-exit-if-changed . && fvm flutter analyze && fvm flutter test && tool/check_rules.sh
git switch -c phase-3
```
If any of these fail, Phase 2b is not finished: stop and report.

**Reconcile with Phase 2b.** This plan was written against Phase 2 (`e425351`). Re-read these files as they are now and fill in the right-hand column in your notes before editing anything:

| This plan assumes (Phase 2) | Check in the 2b code | If different |
|---|---|---|
| Active game state is `SessionActive(session, spinning, spinPlan, orientation, failure, replayCount)`; every emit builds it explicitly (no `copyWith`). | `session_state.dart`, `session_bloc.dart` | Add `liveReveal` the same way 2b added its own fields. If 2b introduced `copyWith`, make sure it cannot carry `liveReveal` forward. |
| `SpinAnimationFinished` and `AppBackgrounded` share one private method. | `session_bloc.dart` | Keep them shared; add the `live` flag. |
| "No active session" is `NoSession`; `ResumePrompt` precedes `SessionActive`. | states + router redirect | Use 2b's states. Everywhere below, "active state" = the state that carries a running session, "session gone" = any transition from it to a state that does not. |
| The announcement line on Revealed / Challenge is `_quote()` in `game_page.dart`. | `game_page.dart` | Replace whatever renders `“${speechLine(session)}”`. |
| The settings button calls `nav.settings()`; the sheet is `settings_sheet_page.dart` with private `_Label`, `_Card`, `_Row`, `_Divider`. | sheet file, `app_navigator.dart` | Add the VOICE section first in the sheet 2b left, reusing its row widgets. |
| No `AppLifecycleListener` exists. | `grep -rn "AppLifecycleListener\|didChangeAppLifecycleState" lib/` | If one exists, add `onHide` to it (D9) and skip the provider in §8. |
| Test harness: `pumpApp`, `tapBar`, `read<T>` in `test/support/harness.dart`. | harness | Extend what is there; keep its signature. |
| `adaptive_platform_ui` is in `pubspec.yaml`. | `grep adaptive_platform_ui pubspec.yaml` | Present → `AdaptiveSwitch` / `AdaptiveSlider` (D14). Absent → Material `Switch` / `Slider`. |

Stop and report (do not improvise) if: 2b removed `replayCount` or `ReplayRequested`; 2b made `SessionBloc` non-singleton; 2b's sheet is no longer a Flutter route (for example a native sheet); 2b already created `lib/platform/native_bridge.dart` with a different shape.

Step order: 1 prefs domain → 2 prefs data + DI → 3 native Swift → 4 `NativeBridge` → 5 `SettingsCubit` → 6 bloc `liveReveal` → 7 `Announcer` → 8 app wiring + lifecycle → 9 UI → 10 rules → 11 widget tests → 12 verify → 13 deferred flows. Write each unit test with its step. Run the static block (§12) after steps 2, 3, 7 and 9.

---

## 1. Prefs domain (pure Dart — no `flutter`, `dart:ui`, `shared_preferences`, `get_it`, `injectable` imports)

### `lib/features/settings/domain/prefs.dart`
```dart
final class Prefs {
  const Prefs({this.announce = true, this.voiceId, this.rate = defaultRate});

  // AVSpeechUtterance rate units (0…1, 0.5 = normal). The usable band is a
  // judgement; tune on a real device.
  static const double minRate = 0.35, maxRate = 0.65, defaultRate = 0.5;

  final bool announce;
  final String? voiceId;      // null = system default voice
  final double rate;

  /// Trust boundary for stored or native values.
  factory Prefs.sanitized({bool? announce, String? voiceId, double? rate});

  Prefs withAnnounce(bool value);
  Prefs withVoice(String? id);
  Prefs withRate(double value);   // goes through sanitized
  // == / hashCode (hand-written)
}

enum VoiceQuality { standard, enhanced, premium }   // wire: default | enhanced | premium

final class Voice {
  const Voice({required this.id, required this.name, required this.language, this.quality = VoiceQuality.standard});
  final String id, name, language;
  final VoiceQuality quality;
  /// "Samantha", "Samantha (Enhanced)", "Samantha (Premium)"
  String get label;
  // == / hashCode
}

/// "Slow" below 0.45, "Fast" above 0.55, else "Normal".
String rateLabel(double rate);

/// premium → enhanced → standard, then name (case-insensitive). Returns a new list.
List<Voice> sortVoices(Iterable<Voice> voices);
```
`Prefs.sanitized`: `announce ?? true`; `voiceId` trimmed, empty → `null`; `rate`: `null`, NaN or infinite → `defaultRate`, else clamped to `minRate…maxRate`. No nullable `copyWith` (it cannot clear `voiceId`) — hence the three `with…` methods.

### `lib/features/settings/domain/prefs_repository.dart`
```dart
abstract interface class PrefsRepository {
  /// Never throws; unreadable values fall back to defaults.
  Prefs load();
  /// Throws StorageFailure.
  Future<void> save(Prefs prefs);
}
```

### `test/prefs_test.dart`
Defaults (`true`, `null`, `0.5`); `sanitized(rate: 0)` → 0.35, `rate: 1` → 0.65, `double.nan` and `double.infinity` → 0.5; `voiceId: '  '` → null; `withVoice(null)` clears; equality; `rateLabel(0.35 / 0.5 / 0.65)` → Slow / Normal / Fast and the two boundaries 0.45 and 0.55 → Normal; `Voice.label` for the three qualities; `sortVoices` order and that the input list is not mutated.

---

## 2. Prefs data and DI

### `lib/features/settings/data/prefs_repository_impl.dart`
```dart
/// The only keys the app may store. End Session never touches them.
const Set<String> prefsKeys = {'announce', 'voiceId', 'rate'};

@LazySingleton(as: PrefsRepository)
class PrefsRepositoryImpl implements PrefsRepository {
  PrefsRepositoryImpl(this._sp);
  final SharedPreferencesWithCache _sp;
}
```
- `load()`: `Prefs.sanitized(announce: _sp.getBool('announce'), voiceId: _sp.getString('voiceId'), rate: _sp.getDouble('rate'))` inside `try`; `on Object` (a stored value of the wrong type throws a `TypeError`) → `const Prefs()`.
- `save(p)`: `setBool('announce', …)`, `setDouble('rate', …)`, then `p.voiceId == null ? remove('voiceId') : setString('voiceId', …)`; `on Exception` → `throw const StorageFailure()`.
- Nothing else in this file. Not unit-tested on the host (D13).

### `lib/core/di/injection.dart` — add to the existing module
```dart
@preResolve
@singleton
Future<SharedPreferencesWithCache> get preferences => SharedPreferencesWithCache.create(
  cacheOptions: const SharedPreferencesWithCacheOptions(allowList: prefsKeys),
);
```
Run codegen; `injection.config.dart` must now pre-resolve it and register `PrefsRepository`.

### `test/support/fake_prefs_repository.dart`
`Prefs stored = const Prefs(); bool failWrites = false; final List<Prefs> saved = [];` — `load()` returns `stored`; `save(p)` throws `const StorageFailure()` when `failWrites`, else appends to `saved` and sets `stored`.

---

## 3. Native (iOS) — the shared channel and speech

Two new files in `ios/Runner/Native/`. This Swift was compiled for the simulator in a scratch copy (Xcode 27.2); its runtime behaviour is not verified. Keep it as is unless the compiler disagrees.

### `ios/Runner/Native/SpeechBridge.swift`
```swift
import AVFoundation
import UIKit

/// AVSpeechSynthesizer behind the spinfolk/native channel. Main thread only.
final class SpeechBridge: NSObject, AVSpeechSynthesizerDelegate {
  /// "done" | "cancelled" | "error"
  var onEvent: ((String) -> Void)?

  private let synth = AVSpeechSynthesizer()
  private var current: AVSpeechUtterance?
  private var interrupted = false
  /// Deactivating inside the delegate callback fails with "session busy" while
  /// the synthesizer still holds the output, which leaves other audio ducked.
  /// Tune on a real device.
  private let deactivateDelay: TimeInterval = 0.3

  override init() {
    super.init()
    synth.delegate = self
    let nc = NotificationCenter.default
    nc.addObserver(self, selector: #selector(didEnterBackground),
                   name: UIApplication.didEnterBackgroundNotification, object: nil)
    nc.addObserver(self, selector: #selector(interruption(_:)),
                   name: AVAudioSession.interruptionNotification, object: nil)
  }

  func speak(text: String, voiceId: String?, rate: Double) throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
    try session.setActive(true)
    let u = AVSpeechUtterance(string: text)
    u.voice = voiceId.flatMap(AVSpeechSynthesisVoice.init(identifier:))
      ?? AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
    u.rate = Float(min(max(rate, Double(AVSpeechUtteranceMinimumSpeechRate)),
                       Double(AVSpeechUtteranceMaximumSpeechRate)))
    // Replacing: `current` moves first, so the old utterance's didCancel is ignored.
    interrupted = false
    current = u
    if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
    synth.speak(u)
  }

  func stop() {
    if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
  }

  func voices(language: String) -> [[String: String]] {
    let prefix = language.lowercased()
    return AVSpeechSynthesisVoice.speechVoices()
      .filter { $0.language.lowercased().hasPrefix(prefix) && !$0.voiceTraits.contains(.isNoveltyVoice) }
      .map {
        ["id": $0.identifier, "name": $0.name, "language": $0.language,
         "quality": $0.quality == .premium ? "premium" : ($0.quality == .enhanced ? "enhanced" : "default")]
      }
  }

  private func finish(_ utterance: AVSpeechUtterance, _ state: String) {
    guard utterance === current else { return }
    current = nil
    DispatchQueue.main.asyncAfter(deadline: .now() + deactivateDelay) { [weak self] in
      guard let self, self.current == nil else { return }  // a new line started meanwhile
      try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    onEvent?(interrupted ? "error" : state)
    interrupted = false
  }

  func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    finish(utterance, "done")
  }

  func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
    finish(utterance, "cancelled")
  }

  @objc private func didEnterBackground() { stop() }

  @objc private func interruption(_ note: Notification) {
    guard current != nil,
          let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
          AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
    interrupted = true
    stop()
  }
}
```

### `ios/Runner/Native/NativeChannel.swift`
```swift
import Flutter
import Foundation

/// Owner of the shared spinfolk/native channel. Main thread only.
/// Phase 4 adds activity.* and url.* here.
final class NativeChannel {
  static let shared = NativeChannel()

  private var channel: FlutterMethodChannel?
  private let speech = SpeechBridge()

  func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "spinfolk/native", binaryMessenger: messenger)
    self.channel = channel
    speech.onEvent = { [weak channel] state in
      channel?.invokeMethod("speech.event", arguments: ["state": state])
    }
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result) ?? result(FlutterMethodNotImplemented)
    }
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "speech.speak":
      guard let text = args["text"] as? String, !text.isEmpty else {
        return result(FlutterError(code: "speech", message: "empty text", details: nil))
      }
      do {
        try speech.speak(text: text, voiceId: args["voiceId"] as? String,
                         rate: args["rate"] as? Double ?? 0.5)
        result(nil)
      } catch {
        result(FlutterError(code: "speech", message: error.localizedDescription, details: nil))
      }
    case "speech.stop":
      speech.stop()
      result(nil)
    case "speech.voices":
      result(speech.voices(language: args["language"] as? String ?? "en"))
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
```

### `ios/Runner/AppDelegate.swift`
In `didInitializeImplicitFlutterEngine`, right after `let messenger = registrar.messenger()`:
```swift
NativeChannel.shared.attach(messenger: messenger)
```
Nothing else changes in this file.

### Add both files to the Runner target
```sh
ruby -rxcodeproj -e '
  p = Xcodeproj::Project.open("ios/Runner.xcodeproj")
  t = p.targets.find { |x| x.name == "Runner" }
  g = p.main_group["Runner"]["Native"]
  t.add_file_references(ARGV.map { |f| g.new_file(f) })
  p.save
' NativeChannel.swift SpeechBridge.swift
grep -c 'SpeechBridge.swift' ios/Runner.xcodeproj/project.pbxproj     # expect 4
grep -c 'NativeChannel.swift' ios/Runner.xcodeproj/project.pbxproj    # expect 4
grep -c 'XCLocalSwiftPackageReference' ios/Runner.xcodeproj/project.pbxproj   # unchanged vs. git show HEAD:…
git diff --stat ios/
fvm flutter build ios --simulator --debug
```
The diff must contain only two file references, two build files, two group children and two Sources entries. `ios/Runner/Info.plist` must be untouched. If the gem mangles the SwiftPM package reference, `git checkout ios/Runner.xcodeproj/project.pbxproj` and hand-add the eight lines by mirroring `ActionBarView.swift`.

What the Swift guarantees (do not "simplify" these away):
- Audio session `.playback` + `.mixWithOthers` + `.duckOthers`, active only between `speak` and the end of the utterance, released with `.notifyOthersOnDeactivation` after `deactivateDelay`.
- A replaced utterance reports nothing; only the current one reports `done` / `cancelled`; an interruption that began while speaking reports `error`.
- Speech stops when the app enters the background (reported as `cancelled`).
- Unknown `voiceId` falls back to the device-language default voice; the stored id is not erased.
- Novelty voices are not listed.

---

## 4. `NativeBridge` — `lib/platform/native_bridge.dart`

```dart
enum SpeechEvent { done, cancelled, error }   // .name is the wire value

@lazySingleton
class NativeBridge {
  NativeBridge() { _channel.setMethodCallHandler(_onCall); }

  static const MethodChannel _channel = MethodChannel('spinfolk/native');

  Stream<SpeechEvent> get speechEvents;          // broadcast

  /// true when iOS accepted the line. Never throws.
  Future<bool> speak(String text, {String? voiceId, required double rate});
  Future<void> stopSpeech();                     // never throws
  /// Installed voices whose language starts with [language]. Never throws; [] on any error.
  Future<List<Voice>> voices(String language);

  @disposeMethod
  Future<void> dispose();                        // handler off, controller closed
}
```
- `speak` → `invokeMethod<void>('speech.speak', {'text': text, 'voiceId': voiceId, 'rate': rate})`; `on PlatformException` and `on MissingPluginException` → `false`.
- `voices` → `invokeListMethod<Object?>('speech.voices', {'language': language})`; keep only entries that are a `Map` with non-empty `String` `id`, `name`, `language`; `quality`: `'enhanced'` → enhanced, `'premium'` → premium, anything else → standard.
- `_onCall`: method `speech.event` with a `Map` whose `state` is one of the enum names → add to the stream. Everything else is ignored (Phase 4 adds `url.open`).
- No `BuildContext`, no bloc imports. Imports `Voice` from the settings domain.

### `test/support/fake_native.dart`
```dart
/// Mock iOS side of spinfolk/native for host tests.
class FakeNative {
  final List<MethodCall> calls = [];
  bool failSpeak = false;
  List<Map<String, String>> voices = [];

  void install();     // setMockMethodCallHandler on TestDefaultBinaryMessengerBinding
  void uninstall();
  /// Simulates iOS → Dart.
  Future<void> send(String method, Object? arguments);
  List<MethodCall> named(String method);
}
```
Handler: record the call; `speech.speak` → throw `PlatformException(code: 'speech')` when `failSpeak`, else `null`; `speech.voices` → `voices`; anything else → `null`. `send` uses `handlePlatformMessage('spinfolk/native', const StandardMethodCodec().encodeMethodCall(MethodCall(method, arguments)), (_) {})`.

### `test/native_bridge_test.dart`
`TestWidgetsFlutterBinding.ensureInitialized()`. Cases: `speak` sends exactly `{text, voiceId, rate}` and returns true; with `failSpeak` → false; with no handler installed (MissingPlugin) → false; `stopSpeech` with no handler does not throw; `voices('en')` sends `{language: 'en'}`, maps three qualities, drops an entry without `id` and a non-map entry, returns `[]` when the handler throws; `send('speech.event', {'state': 'done' / 'cancelled' / 'error'})` arrive in order on `speechEvents`; `{'state': 'bogus'}`, a non-map argument and an unknown method emit nothing and do not throw.

---

## 5. `SettingsCubit` — `lib/features/settings/presentation/cubit/settings_cubit.dart`

```dart
final class SettingsState {
  const SettingsState({required this.prefs, this.voices = const [], this.voiceListOpen = false, this.failure});
  final Prefs prefs;
  final List<Voice> voices;        // sorted
  final bool voiceListOpen;
  final Failure? failure;          // last save failed; shown inline in the sheet
  /// "Default" when voiceId is null or not installed any more.
  String get voiceLabel;
  // == / hashCode (list compared by a private loop)
}

@lazySingleton
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._repo, this._bridge) : super(SettingsState(prefs: _repo.load()));

  Future<void> opened();                       // sheet is opening
  Future<void> announceToggled(bool on);
  void voiceRowTapped();                       // toggles the inline list
  Future<void> voiceSelected(String? id);      // null = Default; closes the list
  void rateChanged(double rate);               // slider tick: emit only
  Future<void> rateCommitted();                // slider released: save
}
```
- Build every new `SettingsState` explicitly (no nullable `copyWith`).
- `opened()`: emit with `voiceListOpen: false`, `failure: null`; then `voices = sortVoices(await _bridge.voices(PlatformDispatcher.instance.locale.languageCode))`; emit unless closed. (`dart:ui` is allowed in a cubit; `BuildContext` is not.)
- One private `_save(Prefs next, {bool closeList = false})`: emit `next` first with `failure: null`; `try { await _repo.save(next); } on Failure catch (f) { emit(same, failure: f); }` (D7).
- `rateChanged` goes through `prefs.withRate` (clamped) and does not save.
- Phase 4 adds one field (`activityStatus`) and one method here.

### `test/settings_cubit_test.dart`
Uses `FakePrefsRepository` and `FakeNative`. Initial state equals stored prefs; `announceToggled(false)` → state and `saved.last`; `rateChanged(0.9)` → 0.65 in state, nothing saved; `rateCommitted()` → saved once; `voiceSelected('x')` → saved, list closed; `voiceSelected(null)` clears; `failWrites` → value kept, `failure is StorageFailure`, next successful save clears it; `opened()` → `speech.voices` called with `{language: 'en'}`, voices sorted, list closed; `voiceLabel` is "Default" for null and for an id that is not in the list, else the voice's label; `voiceRowTapped` toggles.

---

## 6. `SessionBloc` — one field (D2)

`session_state.dart`, active state:
```dart
/// True only in the state emitted for SpinAnimationFinished: the reveal
/// happened live on screen. Backgrounded and restored reveals leave it false,
/// so the Announcer stays silent for them.
final bool liveReveal;      // constructor default false; add to == and hashCode
```
`session_bloc.dart`:
```dart
SpinAnimationFinished() => _finishSpin(emit, live: true),
AppBackgrounded() => _finishSpin(emit, live: false),
```
`_finishSpin` passes `liveReveal: live` to the one state it emits. No other emit sets it. No event is added, nothing else changes.

Extend `test/session_bloc_test.dart`: after `SpinAnimationFinished` → `liveReveal == true`; after `AppBackgrounded` while spinning → `false`; after `ResumeConfirmed` of a revealed session → `false`; after `ModeChosen`, `ReplayRequested`, a failed `ModeChosen` (`failWrites`), and `Passed` → `false`.

---

## 7. `Announcer` — `lib/platform/announcer.dart` (D3, D4, D12)

```dart
/// State: true = show [unavailableText].
@lazySingleton
class Announcer extends Cubit<bool> {
  Announcer(this._bloc, this._bridge, this._settings) : super(false);

  static const String unavailableText = 'Voice unavailable. Read the roles aloud.';
  static const String sampleLine = 'Player 3, give a challenge to Player 7.';

  void start();                 // subscribe; idempotent; called once from main
  Future<void> preview();       // sheet "Play sample": speaks sampleLine
  @override
  Future<void> close();         // cancels both subscriptions
}
```
Private state: the previous `SessionState` (seeded with `_bloc.state` in `start`) and two subscriptions (`_bloc.stream`, `_bridge.speechEvents`).

On each session state (`prev` → `next`), first match wins:

| # | Condition | Action |
|---|---|---|
| 1 | `next` is not the active state | if `prev` was: `stopSpeech()`, emit `false` |
| 2 | `prev` was not active, or the session id changed | nothing (start, resume, play again never speak) |
| 3 | round changed | `stopSpeech()`, emit `false` |
| 4 | `next.liveReveal` and `prefs.announce` | say `speechLine(next.session)` |
| 5 | `next.replayCount > prev.replayCount` | say `speechLine(next.session)` |
| 6 | otherwise | nothing |

"say": `final p = _settings.state.prefs; final ok = await _bridge.speak(line, voiceId: p.voiceId, rate: p.rate); if (!isClosed) emit(!ok);` — a `null` line is skipped. `preview()` is "say" with `sampleLine`. Speech event `error` → emit `true`; `done` / `cancelled` → nothing. No retry, no queue, no timers.

No `BuildContext`, no navigation, no widget imports.

### `test/announcer_test.dart`
Real `SessionBloc` on `FakeSessionRepository` with `Random(1)`, real `NativeBridge` on `FakeNative`, real `SettingsCubit` on `FakePrefsRepository`. Helper `settle() => pumpEventQueue()`.
- Start, spin, `SpinAnimationFinished` → exactly one `speech.speak` with `text == speechLine(state.session)`, `rate == 0.5`, `voiceId == null`.
- Stored prefs `voiceId: 'v1', rate: 0.6` → those values in the call.
- Spin, `AppBackgrounded` → no `speech.speak`.
- Stored revealed session, `AppStarted`, `ResumeConfirmed` → no `speech.speak`.
- `announce: false`: live reveal → no call; `ReplayRequested` → one call.
- `ModeChosen(truth)` → no call; then `ReplayRequested` → call with `'… chose Truth.'`.
- `failSpeak` → state `true`; next successful `ReplayRequested` → `false`.
- `send('speech.event', {'state': 'error'})` → `true`; `'cancelled'` and `'done'` → unchanged.
- `Passed` after a failure → `speech.stop` sent, state `false`.
- `EndConfirmed` (or 2b's equivalent) → `speech.stop` sent, state `false`.
- `preview()` → call with `sampleLine`, also when `announce` is false.
- `start()` twice → still one call per reveal.

---

## 8. App wiring and lifecycle

### `lib/app/app.dart`
- Add to the bloc providers: `BlocProvider<SettingsCubit>.value(value: getIt<SettingsCubit>())` and `BlocProvider<Announcer>.value(value: getIt<Announcer>())`.
- Lifecycle (D9) — skip if 2b already owns a listener and extend that one instead. Add to the repository providers:
  ```dart
  RepositoryProvider<AppLifecycleListener>(
    lazy: false,
    // onHide, not onInactive: Control Centre must not cut a spin short.
    create: (_) => AppLifecycleListener(
      onHide: () => getIt<SessionBloc>().add(const AppBackgrounded()),
    ),
    dispose: (listener) => listener.dispose(),
  ),
  ```
  No `StatefulWidget`, no `WidgetsBindingObserver` mixin.

### `lib/main.dart`
After the first non-loading session state is awaited and before `runApp`:
```dart
getIt<Announcer>().start();
```
(`LiveActivitySync` is Phase 4.)

---

## 9. UI

### 9.1 Announcement row — `game_page.dart` (artboards `Revealed`, `Challenge`, `Crowd60`)
Replace the quoted-line widget on Revealed and Challenge with a private `StatelessWidget` in the same file:
```dart
class _AnnounceRow extends StatelessWidget { const _AnnounceRow(this.session); final Session session; }
```
`BlocBuilder<Announcer, bool>`:
- `true` → `NoticeBanner(Announcer.unavailableText)` and nothing else (the notice replaces the row, as on `Crowd60`).
- `false` → `Row[ speaker icon 18 pt, 10 gap, Expanded(Text('“${speechLine(session)}”', 14 / 19, textSecondary)), 10 gap, Replay button ]`.
  - Speaker icon: a private `CustomPainter` in a 24-unit box, stroke 2, `textSecondary`, round joins: body `M4 9 H8 L13 5 V19 L8 15 H4 Z`, waves `M16.5 8.5 C18 10 18 14 16.5 15.5` and `M19 6 C22 9 22 15 19 18`. Wrapped in `ExcludeSemantics`.
  - Replay button: `Semantics(button: true, label: 'Replay announcement', excludeSemantics: true)` → `GestureDetector(behavior: opaque, onTap: () => context.read<SessionBloc>().add(const ReplayRequested()))` → a box at least `Tokens.touch` high containing a 36-pt capsule, `bgRaised` fill, 1-px `line` border, horizontal padding 14, text `Replay` 14 / w600 / `textPrimary`, `textScaler: besideIsland(context)`. Solid surface, not glass (owner decision). If 2b introduced a shared solid-capsule or adaptive button widget for this kind of control, use that instead of a new one.
- The row sits in the scrolling panel, so large text wraps and scrolls.

### 9.2 Settings button
Its tap handler becomes two forwarded intents: `context.read<SettingsCubit>().opened(); context.read<AppNavigator>().settings();`.

### 9.3 VOICE section — `settings_sheet_page.dart` (artboard `Settings`)
First section of the sheet, above PLAYERS. `BlocBuilder<SettingsCubit, SettingsState>` for the section; `BlocBuilder<Announcer, bool>` for the notice.

1. `NoticeBanner(Announcer.unavailableText)` when the announcer state is `true`; `NoticeBanner(failure.message)` when `state.failure != null`.
2. Section label `VOICE`, then one card with these rows, dividers between them:
   - **Announcements** — `MergeSemantics(Row[ Expanded(Text('Announcements')), switch ])`, min height 50. Switch: `AdaptiveSwitch(value: prefs.announce, onChanged: cubit.announceToggled, activeColor: Tokens.taker)`; without the package `Switch(value:, onChanged:, activeTrackColor: Tokens.taker)`.
   - **Voice** — text `Voice`, trailing `'${state.voiceLabel} ›'` (15, `textSecondary`, one line, ellipsis, `Flexible`), tap → `cubit.voiceRowTapped()`, `Semantics(button: true)`.
   - When `voiceListOpen`: one row per choice, min height 44, indented 16: `Default` first, then `voice.label` for each voice; the selected one ends with `✓` in `taker`; `Semantics(button: true, selected: …)`; tap → `cubit.voiceSelected(id)`. Plain `Column` (the list is short and the sheet already scrolls).
   - **Speed** — padding 14 × 16: `Row[ Text('Speed'), Spacer, Text(rateLabel(prefs.rate), 15, textSecondary) ]`, 10 gap, slider: `AdaptiveSlider(value: prefs.rate, min: Prefs.minRate, max: Prefs.maxRate, onChanged: cubit.rateChanged, onChangeEnd: (_) => cubit.rateCommitted(), activeColor: Tokens.taker)`; without the package the Material `Slider` with the same arguments. Wrap in `Semantics(label: 'Speech speed')`.
   - **Preview** — text `Preview`, trailing tappable `Play sample` (17 / w600 / `taker`, min height 44, `Semantics(button: true)`) → `context.read<Announcer>().preview()`.
3. Footnote: `Only voices already on this iPhone are listed. Nothing downloads.`

Rules for the two adaptive controls (they are platform views on iOS 26): no `Opacity`, `ClipRRect`, transform or Flutter widget on top of them; give the switch its intrinsic size and the slider the full row width with a fixed height (44). Reuse the sheet's existing private row, card, label and divider widgets; give the row widget an optional trailing `Widget` instead of writing a second row type.

Not in this phase: the Live Activity status line.

---

## 10. Rules — `tool/check_rules.sh`

Add before the final echo:
```sh
grep -q 'flutter_tts' pubspec.yaml && bad 'flutter_tts is banned; speech is native (spinfolk/native)'
grep -qE 'NSMicrophoneUsageDescription|UIBackgroundModes' ios/Runner/Info.plist \
  && bad 'no microphone permission and no background modes'
```
Self-test once, then undo: add `# flutter_tts` to `pubspec.yaml` → exit 1; remove → exit 0.

---

## 11. Widget tests

### `test/support/harness.dart`
`pumpApp` additionally: creates and `install()`s a `FakeNative` (uninstall in tear-down); registers `PrefsRepository` (a `FakePrefsRepository`), `NativeBridge`, `SettingsCubit`, `Announcer` in `getIt` (singletons) and calls `announcer.start()`; closes the three in tear-down. New optional parameter `Prefs prefs = const Prefs()`. Expose the two fakes for assertions (top-level `late FakeNative native; late FakePrefsRepository prefsRepo;` set by `pumpApp`). Without the installed mock every reveal would show the voice notice.

### Extend `test/game_flow_test.dart`
- After a settled live reveal: `find.bySemanticsLabel('Replay announcement')` found; `native.named('speech.speak')` has one entry whose `text` equals the on-screen line without the quotes. Tap Replay → two entries. After `tapBar('truth')` the row is still there; Replay → third entry ending in `chose Truth.`.
- `native.failSpeak = true` before the spin → after reveal `find.text(Announcer.unavailableText)` found and the Replay button not found; next round → notice gone.
- Mid-spin hide: `tapBar('spin')`, `pump(const Duration(milliseconds: 300))`, then `tester.binding.handleAppLifecycleStateChanged` with `inactive` and then `hidden` (`AppLifecycleListener` asserts legal transitions, so never jump straight to `hidden`), pump twice → the reveal semantics label is present, `native.named('speech.speak')` is empty; `addTearDown` walks back `inactive` → `resumed`.
- Sheet: open → `Announcements`, `Voice`, `Speed`, `Play sample` found; `native.named('speech.voices')` has one entry. Drive the switch through its callback: `tester.widget<AdaptiveSwitch>(find.byType(AdaptiveSwitch)).onChanged!(false)` (or `Switch`) → `prefsRepo.saved.last.announce == false`. Slider: `onChanged!(0.6)` → label `Fast`, nothing saved; `onChangeEnd!(0.6)` → saved. Tap `Voice` with two fake voices → both labels and `Default` found; tap one → row shows its label, list closed, saved. Tap `Play sample` → a `speech.speak` with `Announcer.sampleLine`.
- End Session (through to the state with no active session) → `prefsRepo.saved` unchanged by the end and `prefsRepo.stored` still holds the edited values.

### Extend `test/layout_test.dart`
Same size × scale matrix as Phase 2. Add visits: sheet with the VOICE section (voice list open, 12 fake voices, one with a 40-character name); Revealed with the Replay row; Revealed with the notice (`failSpeak`); Challenge with the Replay row. `expect(tester.takeException(), isNull)` after each.

---

## 12. Verify (paste the output of each)

```sh
fvm dart run build_runner build --delete-conflicting-outputs
fvm dart format --set-exit-if-changed .
fvm flutter analyze
tool/check_rules.sh
fvm flutter test
fvm flutter build ios --simulator --debug
git diff phase-2b --stat -- pubspec.yaml pubspec.lock ios/Runner/Info.plist   # must print nothing
ls ios/Podfile 2>/dev/null                                                   # must print nothing
grep -rnE "extends StatefulWidget" lib/                                       # spin_stage.dart (+ 2b's allow-list) only
grep -rn "BuildContext" lib/platform/announcer.dart lib/platform/native_bridge.dart   # must print nothing
grep -rnE "activity\.(sync|end|reconcile)|url\.(open|ready)|LiveActivitySync" lib/ ios/Runner/   # must print nothing (Phase 4)
```
Order stays codegen → format → analyze. If `dart format` flags the generated config, run `fvm dart format .` once after codegen.

Trouble guide:
- `MissingPluginException` for `spinfolk/native` in a widget test: the harness did not install `FakeNative` before the bloc emitted.
- A test hangs in `pumpAndSettle` on the sheet: an adaptive control keeps scheduling frames on the host; pump fixed durations for that test and report it.
- `Bad state: GetIt … SharedPreferencesWithCache` in tests: something called `configureDependencies()`; tests must register fakes by hand.
- Swift error about `voiceTraits`: the deployment target dropped below 17.0; fix the target, not the code.

**Suggested commits:** `Phase 3: preferences and settings cubit` (after step 5) · `Phase 3: native speech channel and announcer` (after step 8) · `Phase 3: replay row, voice settings, lifecycle` (after step 11). Evidence folders are ignored and stay out of every commit.

---

## 13. Deferred device flows (write, do not run)

Both files start with the comment `# DEFERRED: run in the post-Phase-5 device pass. Not executed in Phase 3.` Use the steps Phase 2b's flows use to get from launch to a running game (Home → New game → Start Session, or whatever 2b's Maestro flows do); the lines below marked ⟨start a game⟩ stand for that.

### `tool/maestro/phase3.yaml`
```yaml
# DEFERRED: run in the post-Phase-5 device pass. Not executed in Phase 3.
appId: in.appamania.spinfolk
---
- launchApp: { clearState: true }
# ⟨start a game⟩
- tapOn: "Session and settings"
- assertVisible: "Announcements"
- assertVisible: "Play sample"
- tapOn: "Announcements"                 # switch off
- takeScreenshot: docs/plans/phase-3/evidence/p3-sheet-voice
- tapOn: "Done"
- tapOn: "Spin"
- stopApp                                # kill mid-spin (P3-D2)
- launchApp
# ⟨resume the game⟩
- extendedWaitUntil: { visible: "Taker .*", timeout: 5000 }
- assertVisible: "Replay announcement"
- takeScreenshot: docs/plans/phase-3/evidence/p3-resume-after-kill
- tapOn: "Session and settings"
- takeScreenshot: docs/plans/phase-3/evidence/p3-prefs-after-kill   # switch must still be off (P3-D1)
- tapOn: "Done"
```

### `tool/phase3_gate.sh` (`chmod +x`)
```sh
#!/usr/bin/env bash
# DEFERRED: run in the post-Phase-5 device pass. Not executed in Phase 3.
# Kill / restore / corrupt-row checks on a booted simulator.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SIM:?set SIM to a booted simulator UDID}"
APP=in.appamania.spinfolk
mkdir -p docs/plans/phase-3/evidence          # git-ignored
fvm flutter build ios --simulator --debug
xcrun simctl uninstall "$SIM" "$APP" || true
xcrun simctl install "$SIM" build/ios/iphonesimulator/Runner.app
~/.maestro/bin/maestro --device "$SIM" test tool/maestro/phase3.yaml
# P3-D5: SQL-legal corruption of the active session.
xcrun simctl terminate "$SIM" "$APP" || true
DB=$(find "$(xcrun simctl get_app_container "$SIM" "$APP" data)" -name spinfolk.db | head -1)
sqlite3 "$DB" 'DELETE FROM player WHERE seat = 1;'
xcrun simctl launch "$SIM" "$APP"
sleep 3
xcrun simctl io "$SIM" screenshot docs/plans/phase-3/evidence/p3-corrupt.png   # expect the "Couldn't restore the last game" notice
```
Re-check the table and column names against Phase 2b's schema v2 before writing the `sqlite3` line. P3-D3, D4, D6 and D7 are manual; list them in the report as a numbered script with the expected result of each step.

---

## 14. Report format

1. What works.
2. P3-1 … P3-13: PASS / FAIL with real command output. P3-D1 … P3-D7: **NOT VERIFIED (deferred by owner decision)**, plus the manual script.
3. The reconcile table of §0, filled in: what 2b changed and how each item was adapted.
4. Which switch / slider widgets were used (adaptive or Material) and why.
5. Deviations from this file, with the reason.
6. Open questions from `prd.md` §9 still unanswered.
7. Next step (Phase 4): `activity.*` and `url.*` on the existing channel, `LiveActivitySync`, widget extension target, `SceneDelegate` URL handling, status line in the sheet.
