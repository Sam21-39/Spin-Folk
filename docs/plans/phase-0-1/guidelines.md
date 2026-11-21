# Spinfolk — Phase 0 + Phase 1: Implementation Guidelines

Read `prd.md` (this folder) and `docs/spec-v2.md` first. The spec's architecture is fixed. This file gives the order, exact paths, shapes, and verify commands.

## 0. Ground rules

- Every Flutter/Dart command goes through FVM: `fvm flutter …`, `fvm dart …`. Never `fvm global`, never `flutter upgrade`, never `flutter config`.
- All commands run from the repo root `/Users/sp/Dev/Games/Spin-Folk`.
- No `setState` anywhere. Every widget is a `StatelessWidget` except the single temp file `lib/dev/proof_spin.dart`.
- No `showDialog`, `showModalBottomSheet`, `SnackBar`, `ScaffoldMessenger`, `BackdropFilter`.
- Material import is `package:material_ui/material_ui.dart`. Never `package:flutter/material.dart` or `cupertino.dart`. Files that need no Material widget import `package:flutter/widgets.dart`. Confirm this against the generated `lib/main.dart` in step 0.3 before replacing it; if the generated import differs, follow the generated one and report it.
- Dependencies: only those listed in step 0.4. Anything else: stop and ask.
- Report honestly. Paste real command output. A check you could not run is "NOT VERIFIED", with the reason.
- Git: create branch `phase-0-1` from `main`. Commit only if the orchestrator or owner told you to; never push. Suggested commit points are marked.
- If a step fails in a way this file does not cover, stop and report; do not improvise around the architecture.

Simulator used throughout (re-check with `xcrun simctl list devices available`):

```sh
SIM=2938F81B-D7F8-4DFD-81D8-968C25C04F1F     # iPhone 17 Pro, iOS 26.5
SIM18=66C64697-4A19-4C8F-85FE-3FEE1469323D   # iPhone 16e, iOS 18.6 (fallback path)
APP=in.appamania.spinfolk
EVID=docs/plans/phase-0-1/evidence
```

---

# Phase 0 — Baseline

## 0.1 Tooling

```sh
git switch -c phase-0-1
fvm use 3.50.1            # already installed; rewrites .fvmrc and .vscode/settings.json if needed
fvm flutter --version     # expect Flutter 3.50.1, Dart 3.14.x
fvm flutter doctor -v     # record Xcode + CocoaPods lines in the report
```

Expect `.fvmrc` → `{"flutter": "3.50.1"}`. `.fvm/` stays ignored; `.fvmrc` and `.vscode/settings.json` are committed.

## 0.2 Create the app in place

`flutter create` does not overwrite existing files, so move the one-line `.gitignore` aside to get the template's.

```sh
mv .gitignore .gitignore.bak
fvm flutter create . --platforms ios --project-name spinfolk --org in.appamania \
  --description "Offline single-phone Truth-or-Dare party game."
cat .gitignore.bak >> .gitignore && rm .gitignore.bak
printf '\n# Signing material — never commit\n*.mobileprovision\n*.p12\n*.cer\n*.p8\n' >> .gitignore
git status --short        # README.md and CLAUDE_HANDOFF.md must NOT show as modified
grep -n PRODUCT_BUNDLE_IDENTIFIER ios/Runner.xcodeproj/project.pbxproj
```

Expect `in.appamania.spinfolk` (and `.RunnerTests`). If `flutter create` rejects the org, rerun with `--org com.example`, then replace `com.example.spinfolk` with `in.appamania.spinfolk` in `project.pbxproj`, and report it.

## 0.3 Inspect what the template generated (do this before editing)

Read and note in the report:

- `lib/main.dart` — the Material import line (expected `package:material_ui/material_ui.dart`).
- `pubspec.yaml` — expected `material_ui`, `cupertino_icons`, `flutter_lints`.
- `ios/Runner/AppDelegate.swift` — expected:
  ```swift
  @main
  @objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    override func application(…didFinishLaunchingWithOptions…) -> Bool { … }
    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
      GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    }
  }
  ```
- `ios/Runner/SceneDelegate.swift` — expected empty `class SceneDelegate: FlutterSceneDelegate {}`. Leave it untouched in both phases.

If any of these differ from the expectation, adapt to what is generated and say so.

## 0.4 Dependencies, pinned exactly

```sh
fvm flutter pub remove cupertino_icons
fvm flutter pub add flutter_bloc get_it injectable go_router sqflite shared_preferences flutter_tts
fvm flutter pub add --dev injectable_generator build_runner sqflite_common_ffi
# strip carets everywhere except the Dart SDK constraint
sed -i '' -E '/^  sdk:/! s/^(  [a-z_0-9]+: )\^/\1/' pubspec.yaml
fvm flutter pub get
grep -n '\^' pubspec.yaml     # must print only the "sdk: ^3.14.x" line under environment
```

Then in `pubspec.yaml`: set `version: 0.1.0+1`, delete the template's long comment blocks, keep `uses-material-design: true`.

Resulting direct deps — runtime: `flutter` (sdk), `material_ui`, `flutter_bloc`, `get_it`, `injectable`, `go_router`, `sqflite`, `shared_preferences`, `flutter_tts`. Dev: `flutter_test` (sdk), `flutter_lints`, `injectable_generator`, `build_runner`, `sqflite_common_ffi`.

Expected majors (spec A9): flutter_bloc 9.x, get_it 9.x, injectable 3.x, flutter_tts 4.2.x, shared_preferences ≥ 2.3. If the solver picks a different major or fails, stop and paste its output. List the exact pinned versions in the report. `pubspec.lock` is committed.

Do not add: `equatable`, `bloc_test`, `mocktail`, `freezed`, `path`, `provider`, `collection`, `integration_test`, any glass or live-activity package.

## 0.5 iOS project settings

1. Deployment target 17.0:
   ```sh
   sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = 15.0;/IPHONEOS_DEPLOYMENT_TARGET = 17.0;/g' ios/Runner.xcodeproj/project.pbxproj
   grep -c 'IPHONEOS_DEPLOYMENT_TARGET = 17.0;' ios/Runner.xcodeproj/project.pbxproj   # expect 3
   grep -rn 'MinimumOSVersion' ios/Flutter/ || true   # if present, set its value to 17.0
   ```
2. `ios/Runner/Info.plist` — edit by hand (keep the diff small), inside the top-level `<dict>`:
   ```xml
   <key>FlutterDeepLinkingEnabled</key>
   <false/>
   <key>UIUserInterfaceStyle</key>
   <string>Dark</string>
   ```
   Confirm `CFBundleDisplayName` is `Spinfolk`. Do not add the URL scheme, `NSSupportsLiveActivities`, microphone text, or background modes.
3. The first iOS build generates `ios/Podfile` (flutter_tts is CocoaPods-only). After step 0.9's first build, uncomment and set `platform :ios, '17.0'` in `ios/Podfile`, rebuild, and commit `Podfile` and `Podfile.lock`.

## 0.6 Dart files

Delete the template `lib/main.dart` content and `test/widget_test.dart`. Create:

**`lib/app/tokens.dart`** — one `abstract final class Tokens` with `static const` values from the spec's DESIGN TOKENS, nothing else:
- Colors: `bgBase 0xFF0B1424`, `bgSurface 0xFF121E33`, `bgRaised 0xFF1A2A45`, `line 0xFF2A3B5E`, `taker 0xFF2DD4BF`, `giver 0xFFFF7A59`, `textPrimary 0xFFF2F5FA`, `textSecondary 0xFFA9B6CC`, `textTertiary 0xFF8191AB`.
- Spacing: `s4, s8, s12, s16, s24, s32, s48`, `margin = 20.0`.
- Radii: `r12, r20, r28`.
- No durations, no text styles yet (added when first used).

**`lib/core/di/injection.dart`**
```dart
import 'dart:math';

import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'injection.config.dart';

final GetIt getIt = GetIt.instance;

// Synchronous until the first @preResolve dependency (Database, prefs) lands
// in a later phase; it then becomes Future<void> and main() awaits it.
@InjectableInit()
void configureDependencies() => getIt.init();

@module
abstract class CoreModule {
  @lazySingleton
  Random get random => Random();
}
```
Check the injectable version you pinned: its README shows the current `@InjectableInit` form (defaults in 3.0.0: `initializerName: 'init'`, `asExtension: true`). Follow the README if it differs.

**`lib/app/router.dart`**
```dart
@module
abstract class RouterModule {
  @lazySingleton
  GoRouter get router => GoRouter(
    initialLocation: '/new',
    routes: [GoRoute(path: '/new', builder: (_, _) => const _BaselinePage())],
  );
}
```
`_BaselinePage` is a private `StatelessWidget` in the same file: `Scaffold(body: Center(child: Text('Spinfolk')))`. No redirect, no `refreshListenable` yet.

**`lib/app/app.dart`**
```dart
class SpinfolkApp extends StatelessWidget {
  const SpinfolkApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Spinfolk',
    debugShowCheckedModeBanner: false,   // clean evidence screenshots
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Tokens.bgBase,
    ),
    routerConfig: getIt<GoRouter>(),
  );
}
```

**`lib/main.dart`**
```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies();
  runApp(const SpinfolkApp());
}
```

**`test/app_smoke_test.dart`** — one `testWidgets`: `configureDependencies()`, `pumpWidget(const SpinfolkApp())`, `pumpAndSettle()`, `expect(find.text('Spinfolk'), findsOneWidget)`; `tearDown(getIt.reset)`.

Not created now: `app_navigator.dart`, `bloc_listenable.dart`, `failure.dart`, any `features/` folder.

## 0.7 Codegen

```sh
fvm dart run build_runner build --delete-conflicting-outputs
```
Expect `lib/core/di/injection.config.dart` registering `Random` and `GoRouter`. Commit the generated file. Do not hand-edit it.

## 0.8 `tool/check_rules.sh`

```sh
#!/usr/bin/env bash
# Architecture rules from docs/spec-v2.md A2/A3. Exit 1 on any violation.
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
bad() { echo "FAIL: $1"; fail=1; }
src() { grep -rnE --include='*.dart' "$@"; }

src 'setState\(' lib/ && bad 'setState in lib/'
src 'showDialog|showModalBottomSheet|ScaffoldMessenger|SnackBar|BackdropFilter' lib/ \
  && bad 'dialogs/snackbars must be routes or inline state; glass is never faked'
src "package:flutter/(material|cupertino)\.dart" lib/ test/ \
  && bad 'deprecated import; use package:material_ui/material_ui.dart'

# StatefulWidget is allowed only to own an AnimationController.
src -l 'extends StatefulWidget' lib/ \
  | grep -v -e '^lib/features/game/presentation/widgets/spin_stage.dart$' \
            -e '^lib/dev/proof_spin.dart$' \
  && bad 'StatefulWidget outside the allowlist'

layers=$(find lib/features -type d \( -name domain -o -name data -o -name bloc -o -name cubit \) 2>/dev/null)
[ -n "$layers" ] && src 'BuildContext' $layers && bad 'BuildContext in domain/data/bloc/cubit'

domain=$(find lib/features -type d -name domain 2>/dev/null)
[ -n "$domain" ] && src "package:(flutter|sqflite|get_it)" $domain && bad 'domain must be pure Dart'

[ "$fail" -eq 0 ] && echo 'check_rules: OK'
exit "$fail"
```
`chmod +x tool/check_rules.sh`. The `lib/dev/proof_spin.dart` allowlist line is removed in Phase 2 together with `lib/dev/`.

Self-test once, then undo: add `// setState(` to any lib file → script must exit 1; remove it → exit 0.

## 0.9 Docs touch-up

- `README.md`: replace only the "Planned stack" paragraph with: Flutter 3.50.1 via FVM, flutter_bloc, get_it + injectable, go_router, sqflite, shared_preferences, native SwiftUI glass islands, ActivityKit; and point the "Implementation brief" link at `docs/spec-v2.md`. Full README is Phase 5.
- `CLAUDE_HANDOFF.md`: add one line at the top: `> Superseded by docs/spec-v2.md where they disagree (GetX → BLoC, GetStorage → sqflite).`

## 0.10 Phase 0 verify (paste output of each)

```sh
fvm dart run build_runner build --delete-conflicting-outputs
fvm dart format --set-exit-if-changed .
fvm flutter analyze
fvm flutter test
tool/check_rules.sh

fvm flutter build ios --simulator --debug
# first build creates ios/Podfile → set platform :ios, '17.0' → rebuild once

xcrun simctl boot "$SIM" 2>/dev/null; xcrun simctl bootstatus "$SIM" -b
open -a Simulator
xcrun simctl install "$SIM" build/ios/iphonesimulator/Runner.app
xcrun simctl launch "$SIM" "$APP"
sleep 4
mkdir -p "$EVID"
xcrun simctl io "$SIM" screenshot "$EVID/p0-baseline.png"

PL=build/ios/iphonesimulator/Runner.app/Info.plist
for k in CFBundleIdentifier MinimumOSVersion FlutterDeepLinkingEnabled UIUserInterfaceStyle; do
  /usr/libexec/PlistBuddy -c "Print :$k" "$PL"
done
```
Expected: format exit 0; analyze "No issues found!"; tests pass; `check_rules: OK`; plist prints `in.appamania.spinfolk`, `17.0`, `false`, `Dark`. Open the screenshot with the Read tool and describe what it actually shows.

If `dart format` flags the generated config, run `fvm dart format .` after codegen and keep the order codegen → format → analyze.

Analyzer infos originating inside dependencies are acceptable (spec A1-2); infos or warnings in `lib/`, `test/`, `tool/` are not.

**Suggested commit:** `Phase 0: pinned Flutter 3.50.1 baseline with DI and router skeleton`.

---

# Phase 1 — Native glass proof

Order: Swift islands → Dart wrappers → SetupCubit → proof harness → evidence.

## 1.1 Swift files

Create under `ios/Runner/Native/`. iOS 17 minimum; glass under `if #available(iOS 26.0, *)`, otherwise `.ultraThinMaterial` in the identical shape.

### `Glass.swift`
One shared modifier, nothing else:
```swift
import SwiftUI

extension View {
  /// Liquid Glass on iOS 26+, ultra-thin material before that. Same shape either way.
  @ViewBuilder
  func glassBackground<S: Shape>(_ shape: S) -> some View {
    if #available(iOS 26.0, *) {
      self.glassEffect(.regular, in: shape)
    } else {
      self.background(.ultraThinMaterial, in: shape)
    }
  }
}
```

### `PickerView.swift`
Contains four types:

- `@Observable final class PickerModel` — `var min = 2`, `var max = 60`, `var value = 8`, `var onChange: ((Int) -> Void)?`, and
  `func apply(_ args: Any?)`: `guard let d = args as? [String: Any]`; read `min`, `max`, `value` as `Int`; ignore the whole update if `min > max`; clamp `value` into `min...max`; assign only fields that changed.
- `struct PickerIsland: View` — `@Bindable`/plain reference to the model:
  ```swift
  Picker("Number of players", selection: Binding(
    get: { model.value },
    set: { v in guard v != model.value else { return }; model.value = v; model.onChange?(v) }
  )) {
    ForEach(model.min...model.max, id: \.self) { Text("\($0) players").tag($0) }
  }
  .pickerStyle(.wheel)
  .fontDesign(.rounded)
  .dynamicTypeSize(...DynamicTypeSize.accessibility2)
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .glassBackground(RoundedRectangle(cornerRadius: 28, style: .continuous))
  ```
  `onChange` fires only for user-driven changes (it lives in the binding setter); values arriving through `apply` must not echo back.
- `final class PickerPlatformView: NSObject, FlutterPlatformView`
  ```swift
  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger)
  func view() -> UIView      // host.view
  deinit                     // channel.setMethodCallHandler(nil)
  ```
  In `init`: create `FlutterMethodChannel(name: "spinfolk/picker/\(viewId)", binaryMessenger: messenger)`; `model.apply(args)`; `host = UIHostingController(rootView: PickerIsland(model: model))`; `host.view.backgroundColor = .clear`; `host.view.isOpaque = false`; `host.safeAreaRegions = []`; then
  `model.onChange = { [weak self] v in self?.channel.invokeMethod("changed", arguments: ["value": v]) }` and
  `channel.setMethodCallHandler { [weak self] call, result in … }` handling `"config"` → `model.apply(call.arguments); result(nil)`, anything else → `result(FlutterMethodNotImplemented)`.
- `final class PickerFactory: NSObject, FlutterPlatformViewFactory`
  ```swift
  init(messenger: FlutterBinaryMessenger)
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol   // FlutterStandardMessageCodec.sharedInstance()
  ```
  Without `createArgsCodec` the creation params arrive as `nil`.

### `ActionBarView.swift`
Same four-type layout:

- `struct ActionItem: Identifiable, Equatable { let id: String; let label: String; let style: String; let enabled: Bool }`.
- `@Observable final class ActionBarModel` — `var items: [ActionItem] = []`, `var layout = "stack"`, `var onTap: ((String) -> Void)?`, `func apply(_ args: Any?)`: parse `items` with `compactMap` (skip entries missing `id` or `label`; unknown `style` → `"secondary"`; missing `enabled` → `true`); `layout` is `"row"` or else `"stack"`.
- `struct ActionBarIsland: View`
  - Container: `model.layout == "row" ? AnyLayout(HStackLayout(spacing: 12)) : AnyLayout(VStackLayout(spacing: 10))`, wrapped in `GlassEffectContainer` on iOS 26+, then `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)`, `.fontDesign(.rounded)`, `.dynamicTypeSize(...DynamicTypeSize.accessibility2)`.
  - Each item: `Button { model.onTap?(item.id) } label: { Text(item.label).font(.headline).frame(maxWidth: .infinity, minHeight: item.style == "primary" ? 64 : 50) }` + `.disabled(!item.enabled)`.
  - Style, iOS 26+: `primary` → `.buttonStyle(.glassProminent)`; `secondary`, `choice` → `.buttonStyle(.glass)`; `destructive` → `.buttonStyle(.glass)` with coral label `Color(red: 1.0, green: 0x7A / 255, blue: 0x59 / 255)`. All `.buttonBorderShape(.capsule)`.
  - Style, iOS 17–25: `.buttonStyle(.plain)` and `.background(.ultraThinMaterial, in: Capsule())`, same heights and label colors, `.contentShape(Capsule())`.
  - Primary tint: start with `.tint(.white.opacity(0.2))`, compare to `docs/design/project/Components.dc.html` ("Spin action") and `NewGame.dc.html` ("Start Session"), adjust once. Record the value chosen.
  - Disabled state must differ by more than color: the Dart side changes the label ("Spinning…").
  - The `Text` label is the VoiceOver label; add nothing else.
- `ActionBarPlatformView` and `ActionBarFactory` — identical shape to the picker's, channel `spinfolk/actionbar/<viewId>`, native → Dart `invokeMethod("tap", arguments: ["id": id])`, Dart → native `"config"` updates the model in place (the view is never recreated).

Lifetime rules for both platform views (review checklist, P1-10): every closure stored on the model or channel captures `[weak self]`; `deinit` clears the channel handler; nothing stores the hosting controller outside the platform view.

### Register the factories — `ios/Runner/AppDelegate.swift`
Add after the existing `GeneratedPluginRegistrant.register(...)` line:
```swift
let registrar = engineBridge.applicationRegistrar
let messenger = registrar.messenger()
registrar.register(PickerFactory(messenger: messenger), withId: "spinfolk/picker")
registrar.register(ActionBarFactory(messenger: messenger), withId: "spinfolk/actionbar")
```
(`registerViewFactory:withId:` and `messenger` are declared on `FlutterBaseRegistrar`, which `FlutterApplicationRegistrar` extends — verified in `Flutter.framework/Headers/FlutterPlugin.h`. If the Swift importer names differ, use Xcode's error fix-it and report the actual names.)

### Add the files to the Xcode target
The project uses explicit file references, so files on disk are not compiled until added:
```sh
ruby -rxcodeproj -e '
  p = Xcodeproj::Project.open("ios/Runner.xcodeproj")
  t = p.targets.find { |x| x.name == "Runner" }
  g = p.main_group["Runner"].new_group("Native", "Native")
  t.add_file_references(ARGV.map { |f| g.new_file(f) })
  p.save
' Glass.swift PickerView.swift ActionBarView.swift
git diff --stat ios/Runner.xcodeproj/project.pbxproj
grep -c 'PickerView.swift' ios/Runner.xcodeproj/project.pbxproj    # expect 4
```
Check the diff contains only the new group, three file references, and three Sources entries (plus harmless reformatting). If the gem fails or mangles the SwiftPM package reference, `git checkout ios/Runner.xcodeproj/project.pbxproj` and hand-add entries mirroring the four `SceneDelegate.swift` lines (PBXBuildFile, PBXFileReference, group child, Sources phase).

Build once now (`fvm flutter build ios --simulator --debug`) to catch Swift errors before writing Dart.

## 1.2 Dart platform wrappers — `lib/platform/`

### `native_island.dart` — shared host
```dart
/// Owns the per-view MethodChannel for one native island instance.
/// Scoped to the island's subtree by RepositoryProvider, so no State class
/// and no app-wide singleton (two action bars can coexist mid-transition).
class NativeViewLink {
  NativeViewLink(this.viewType);
  final String viewType;

  void Function(String method, Object? arguments)? onCall;

  void attach(int viewId);                    // onPlatformViewCreated
  void config(Map<String, Object?> config);   // idempotent
  void dispose();
}
```
Behaviour:
- `attach`: clear the handler on any previous channel; create `MethodChannel('$viewType/$viewId')`; set a handler that forwards `(call.method, call.arguments)` to `onCall`; then send the latest stored config once (closes the race between first build and view creation).
- `config`: `final encoded = jsonEncode(config)`; return if equal to the last stored encoding; store it; if attached, `invokeMethod('config', config)`. Comment the `jsonEncode` comparison: configs are small nested maps and `mapEquals` is shallow.
- A failed `invokeMethod` (`MissingPluginException`, `PlatformException` during teardown) is caught and `debugPrint`ed; it must not become an unhandled async error.
- `dispose`: clear the handler, drop the channel.

```dart
class NativeIsland extends StatelessWidget {
  const NativeIsland({
    required this.viewType,
    required this.config,
    required this.onCall,
    super.key,
  });
  …
  @override
  Widget build(BuildContext context) => RepositoryProvider<NativeViewLink>(
    create: (_) => NativeViewLink(viewType),
    dispose: (link) => link.dispose(),
    child: _IslandView(viewType: viewType, config: config, onCall: onCall),
  );
}
```
`_IslandView.build`:
```dart
// Deliberate side effect in build: this is the sync point from declarative
// config to the native view, and NativeViewLink.config is idempotent.
context.read<NativeViewLink>()
  ..onCall = onCall
  ..config(config);
if (defaultTargetPlatform != TargetPlatform.iOS) return const SizedBox.expand();  // widget tests
return UiKitView(
  viewType: viewType,
  creationParams: config,                                  // correct first frame
  creationParamsCodec: const StandardMessageCodec(),
  onPlatformViewCreated: context.read<NativeViewLink>().attach,
  gestureRecognizers: const {
    Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
  },
);
```
Imports: `dart:convert`, `package:flutter/foundation.dart`, `package:flutter/gestures.dart`, `package:flutter/services.dart`, `package:flutter/widgets.dart`, `package:flutter_bloc/flutter_bloc.dart`.

Do not wrap `UiKitView` in `ClipRRect`, `Opacity`, or any transform, and never place Flutter widgets on top of an island: shapes belong to the native side, and overlapping Flutter content forces extra overlay layers.

### `native_picker.dart`
```dart
class NativePicker extends StatelessWidget {
  const NativePicker({
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
    super.key,
  });
  final int min, max, value;
  final ValueChanged<int> onChanged;
}
```
`build` returns `NativeIsland(viewType: 'spinfolk/picker', config: {'min': min, 'max': max, 'value': value}, onCall: …)`. `onCall` accepts only `method == 'changed'` with a `Map` whose `value` is an `int`; anything else is dropped.

### `native_action_bar.dart`
```dart
enum ActionBarStyle { primary, secondary, destructive, choice }
enum ActionBarLayout { stack, row }

class ActionBarItem {
  const ActionBarItem({
    required this.id,
    required this.label,
    this.style = ActionBarStyle.secondary,
    this.enabled = true,
  });
  final String id, label;
  final ActionBarStyle style;
  final bool enabled;
}

class NativeActionBar extends StatelessWidget {
  const NativeActionBar({
    required this.items,
    required this.onTap,
    this.layout = ActionBarLayout.stack,
    super.key,
  });
  final List<ActionBarItem> items;
  final ActionBarLayout layout;
  final ValueChanged<String> onTap;
}
```
Config map: `{'items': [for (final i in items) {'id': i.id, 'label': i.label, 'style': i.style.name, 'enabled': i.enabled}], 'layout': layout.name}`. `onCall` accepts only `method == 'tap'` with a `Map` whose `id` is a `String`. The enum `.name` values are the wire contract (spec A7) — do not rename them.

## 1.3 `SetupCubit` — `lib/features/setup/presentation/cubit/setup_cubit.dart`

```dart
final class SetupState {
  const SetupState({this.count = 8});     // artboards centre the wheel on 8
  final int count;
  // hand-written == and hashCode (no equatable)
}

@injectable
class SetupCubit extends Cubit<SetupState> {
  SetupCubit() : super(const SetupState());

  static const int minPlayers = 2;
  static const int maxPlayers = 60;

  /// Input comes from a native channel, so out-of-range values are ignored.
  void countChanged(int count) {
    if (count < minPlayers || count > maxPlayers) return;
    emit(SetupState(count: count));
  }
}
```
No names, no `BuildContext`, no navigation. Rerun codegen. Provide it app-wide in `lib/app/app.dart`: wrap `MaterialApp.router` in `BlocProvider(create: (_) => getIt<SetupCubit>(), child: …)`.

## 1.4 Temporary proof harness — `lib/dev/` (deleted in Phase 2)

Every file starts with `// TEMP(phase-1): glass proof harness. Delete in Phase 2.`

**`proof_cubit.dart`** — plain class, constructed directly by the page (not registered with injectable).
- `ProofState { bool spinning; bool choices; String lastTap; int flutterTaps; String frames; }` with `==`/`hashCode`.
- `tapped(String id)`: sets `lastTap`; `spin` → `spinRequested()`; `choices` → `choices = true`; `truth`/`dare` → `choices = false`. (`end` is handled by the page, which also calls `SetupCubit.countChanged(SetupCubit.minPlayers)`.)
- `flutterTapped()`: increments `flutterTaps`.
- `spinRequested()`: return if `spinning`; clear collected timings; start collecting; emit `spinning: true`.
- `spinFinished()`: emit `spinning: false`; keep collecting for 1.5 s (timings arrive in batches up to about a second late), then, if not closed, emit `frames`.
- Frame collection: register `SchedulerBinding.instance.addTimingsCallback` in the constructor, remove it in `close()`. While collecting, record `timing.totalSpan` for each `FrameTiming`.
- `frames` format, exactly: `Frames: <n> · worst <x.x> ms · >16.7ms: <a> · >33ms: <b>`.

**`test_painter.dart`** — `CustomPainter` with `super(repaint: animation)`. Full-canvas, high-contrast, saturated: a sweep-gradient wheel (red, yellow, green, cyan, blue, magenta) rotated by `animation.value * 2π * 6`, plus white diagonal stripes about 14 pt wide every 56 pt translated with the animation. The pattern must cover the whole screen so both glass shapes have moving content behind them. `shouldRepaint => false` (repaint is driven by the listenable).

**`proof_spin.dart`** — the only `StatefulWidget` (allowlisted). It mirrors the future `SpinStage` contract.
- `State` with `SingleTickerProviderStateMixin`; `late final AnimationController _c` created in `initState`, disposed in `dispose`. **No `setState`.**
- A status listener on `_c`: on `AnimationStatus.completed` → `context.read<ProofCubit>().spinFinished()`.
- `build`: `BlocListener<ProofCubit, ProofState>(listenWhen: (a, b) => !a.spinning && b.spinning, listener: (context, _) { _c.duration = MediaQuery.disableAnimationsOf(context) ? const Duration(milliseconds: 600) : const Duration(seconds: 10); _c.forward(from: 0); }, child: CustomPaint(painter: TestPainter(_c), size: Size.infinite))`.

**`glass_proof_page.dart`** — `StatelessWidget`.
- `BlocProvider(create: (_) => ProofCubit())` around a `Scaffold` whose body is a `Stack`:
  1. `Positioned.fill(child: ProofSpin())` — the moving background, under everything.
  2. `SafeArea` → `Padding(horizontal: Tokens.margin)` → `Column`:
     - `SizedBox(height: 216, child: NativePicker(min: SetupCubit.minPlayers, max: SetupCubit.maxPlayers, value: <SetupCubit count>, onChanged: context.read<SetupCubit>().countChanged))`
     - Status block (Flutter `Text`, each on a dark `Tokens.bgSurface` pill so it stays readable): `Players: <count>`, `Last tap: <id>`, `<frames>`, `Reduce motion: on|off` (from `MediaQuery.disableAnimationsOf(context)`).
     - `GestureDetector(onTap: proof.flutterTapped, child: Text('Flutter taps: <n>'))` — minimum 44 pt tall; proves Flutter still receives touches between the islands.
     - `Spacer()`
     - `SizedBox(height: 184, child: NativeActionBar(...))` (64 + 50 + 50 + 2 × 10)
- Action bar config from `ProofState`:
  - `choices == false` → `layout: stack`, items `spin` (primary; label `spinning ? 'Spinning…' : 'Spin'`; `enabled: !spinning`), `choices` (secondary, `Show choices`), `end` (destructive, `End Session`).
  - `choices == true` → `layout: row`, items `truth` (choice, `Truth`), `dare` (choice, `Dare`).
- `onTap: (id) { proof.tapped(id); if (id == 'end') setup.countChanged(SetupCubit.minPlayers); }` — callbacks only forward intent.
- Use `BlocBuilder`/`BlocSelector` for all state reads. No Flutter widget overlaps either island.

**Router:** in `lib/app/router.dart` change the `/new` builder to `const GlassProofPage()` with a `// TEMP(phase-1)` comment, and delete `_BaselinePage`.

## 1.5 Tests (plain `flutter_test`; no bloc_test, no mocktail)

- `test/setup_cubit_test.dart`: initial count 8; `countChanged(12)` → 12; `countChanged(1)` and `countChanged(61)` leave the state unchanged; 2 and 60 accepted.
- `test/native_island_test.dart`: with `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('spinfolk/picker/7'), …)` recording calls: `config(a)` before `attach(7)` sends nothing; `attach(7)` sends `a` once; `config(a)` again sends nothing; `config(b)` sends `b`; a simulated incoming `changed` call reaches `onCall`; after `dispose()` nothing more is sent.
- `test/app_smoke_test.dart`: update the expectation to `find.text('Players: 8')`. (On the test host `defaultTargetPlatform` is not iOS, so islands render as empty boxes.)

## 1.6 Phase 1 verify

Static checks:
```sh
fvm dart run build_runner build --delete-conflicting-outputs
fvm dart format --set-exit-if-changed .
fvm flutter analyze
fvm flutter test
tool/check_rules.sh
```

Build, install, launch:
```sh
fvm flutter build ios --simulator --debug
xcrun simctl boot "$SIM" 2>/dev/null; xcrun simctl bootstatus "$SIM" -b; open -a Simulator
xcrun simctl install "$SIM" build/ios/iphonesimulator/Runner.app
xcrun simctl launch "$SIM" "$APP"
sleep 4 && xcrun simctl io "$SIM" screenshot "$EVID/p1-01-idle.png"
```

Interaction run — write `tool/phase1_proof.yaml` (temp; deleted in Phase 2):
```yaml
appId: in.appamania.spinfolk
---
- launchApp
- assertVisible: "Players: 8"
- swipe: { start: "50%, 22%", end: "50%, 14%" }     # native wheel; adjust to the picker's centre
- assertNotVisible: "Players: 8"
- tapOn: "Flutter taps: 0"
- assertVisible: "Flutter taps: 1"
- tapOn: "End Session"
- assertVisible: "Players: 2"
- tapOn: "Show choices"
- assertVisible: "Truth"
- tapOn: "Dare"
- assertVisible: "Last tap: dare"
- tapOn: "Spin"
- assertVisible: "Spinning…"
- extendedWaitUntil: { visible: "Frames: .*", timeout: 20000 }
- assertVisible: "Spin"
```
```sh
~/.maestro/bin/maestro --device "$SIM" test tool/phase1_proof.yaml
```
Maestro matches the whole element text, so `"Spin"` does not match `"Spinning…"`. If Maestro cannot see Flutter text, check that semantics are on before changing code. If Maestro cannot run on this Xcode/runtime at all, try one iOS 26.4 simulator, then report P1-1, P1-2, P1-4 as NOT VERIFIED and include this manual script for the owner: swipe the wheel; tap "Flutter taps"; tap End Session; tap Show choices; tap Dare; tap Spin — with the expected on-screen text after each.

Glass sampling and jank (run the spin twice; the first run warms up the JIT):
```sh
# run 1: warm-up — tap Spin through Maestro or by hand, wait for "Frames:"
# run 2: start the spin, then
sleep 3 && xcrun simctl io "$SIM" screenshot "$EVID/p1-02-spin-a.png"
sleep 3 && xcrun simctl io "$SIM" screenshot "$EVID/p1-03-spin-b.png"
sleep 8 && xcrun simctl io "$SIM" screenshot "$EVID/p1-04-frames.png"
```
Open all three with the Read tool.
- P1-3 passes only if the stripes and colors are visibly present inside the picker card and inside the capsules (blurred or refracted), and their position differs between shots a and b. Flat grey, black, or a frozen pattern inside the glass is a **fail**: stop, attach the screenshots, describe what is seen, and propose native layout options. Do not add `BackdropFilter` or any imitation.
- P1-5: copy the `Frames:` line verbatim. Pass = `n ≥ 570` and `>33ms ≤ 2`. Otherwise report as failing, with the numbers; do not tune the thresholds. State that this is a debug build on a simulator.

Accessibility settings:
```sh
xcrun simctl spawn "$SIM" defaults write com.apple.Accessibility ReduceMotionEnabled -bool YES
xcrun simctl spawn "$SIM" defaults write com.apple.Accessibility EnhancedBackgroundContrastEnabled -bool YES   # Reduce Transparency
xcrun simctl terminate "$SIM" "$APP"; xcrun simctl launch "$SIM" "$APP"
sleep 4 && xcrun simctl io "$SIM" screenshot "$EVID/p1-05-reduced.png"
```
Pass = the page shows `Reduce motion: on`, the islands render more opaque but legible, and a spin ends in about 600 ms. If the screenshot shows no change, the defaults keys did not take on this runtime: try toggling through Settings → Accessibility with a short Maestro flow (`appId: com.apple.Preferences`); if that also fails, report P1-6 as NOT VERIFIED. Afterwards set both keys back to `NO` and confirm with a relaunch.

Fallback path (iOS 18.6):
```sh
xcrun simctl boot "$SIM18" 2>/dev/null; xcrun simctl bootstatus "$SIM18" -b
xcrun simctl install "$SIM18" build/ios/iphonesimulator/Runner.app
xcrun simctl launch "$SIM18" "$APP"
sleep 4 && xcrun simctl io "$SIM18" screenshot "$EVID/p1-06-ios18.png"
xcrun simctl shutdown "$SIM18"
```
Pass = launches without a crash; picker card and capsules show material blur in the same shapes.

Crash or blank screen: `xcrun simctl launch --console-pty "$SIM" "$APP"` and read the log; a "unregistered view type" error means the factory id or the `AppDelegate` registration is wrong; `nil` creation args mean `createArgsCodec` is missing.

**Suggested commit:** `Phase 1: native glass islands, SetupCubit, and proof harness`.

## 1.7 Report format (both phases)

1. What works.
2. Each acceptance check from `prd.md` §7 by id: PASS / FAIL / NOT VERIFIED, with the real command output or the screenshot path and a one-line description of what the image shows.
3. Exact pinned versions; template facts that differed from §0.3; the primary tint value chosen.
4. Blockers and anything done differently from this file, with the reason.
5. Next step (Phase 2), including the cleanup list: delete `lib/dev/`, `tool/phase1_proof.yaml`, the `proof_spin.dart` allowlist line in `tool/check_rules.sh`, and the `TEMP(phase-1)` route.
