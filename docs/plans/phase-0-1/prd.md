# Spinfolk — Phase 0 (baseline) + Phase 1 (native glass proof): Technical PRD

Date: 2026-11-22 · Spec: `docs/spec-v2.md` (authoritative; architecture fixed) · Companion: `guidelines.md` in this folder.

## 1. Problem

The repo holds only docs. Before any gameplay is written, two things must be true and proven on a simulator:

1. **Phase 0** — a pinned, reproducible Flutter project exists with the fixed stack wired end to end (FVM pin, pinned deps, get_it/injectable codegen, go_router stub), and it builds, launches and analyzes clean.
2. **Phase 1** — the riskiest product assumption holds: two SwiftUI "islands" (`NativePicker`, `NativeActionBar`) hosted in `UiKitView` render real Liquid Glass that **samples the Flutter content behind them**, pass touches correctly, talk to cubits over per-view channels, and do not cause jank while Flutter animates underneath.

If Phase 1 fails, the layout approach changes before any real screens are built. That is why it comes first.

## 2. Verified facts (checked 2026-11-22, not assumed)

| Fact | Source |
|---|---|
| Flutter 3.50.1 installed in the FVM cache; `.fvmrc` pins `3.50.1`. Dart 3.14.x. | `~/fvm/versions/3.50.1`, `.fvmrc` |
| App templates of 3.50.0 and 3.50.1 are byte-identical. | `diff -rq` of `packages/flutter_tools/templates/app` |
| Template imports **`package:material_ui/material_ui.dart`** and depends on `material_ui: ^1.1.0`. `package:flutter/material.dart` and `cupertino.dart` carry `@Deprecated('Use package:material_ui/material_ui.dart instead…')`. `package:flutter/widgets.dart` is not deprecated. | template `main.dart.tmpl`, `pubspec.yaml.tmpl`, `packages/flutter/lib/material.dart` |
| iOS template: `AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate` with `didInitializeImplicitFlutterEngine(_ engineBridge:)`; empty `SceneDelegate: FlutterSceneDelegate`; scene manifest in Info.plist. | template `ios.tmpl/Runner/*.swift`, `Info.plist.tmpl` |
| `FlutterImplicitEngineBridge` exposes `pluginRegistry` and `applicationRegistrar`. `registerViewFactory:withId:` and `messenger` live on `FlutterBaseRegistrar`, so the **application registrar can register platform-view factories** directly (no fake plugin registrar needed). | `Flutter.framework/Headers/FlutterEngine.h`, `FlutterPlugin.h` |
| Template `project.pbxproj` is `objectVersion = 54` with explicit file references (no synchronized folders) and deployment target **15.0**. New Swift files must be added to the project file. | `project.pbxproj.tmpl` |
| Template already references the SwiftPM plugin package; `flutter_tts` 4.2.5 ships a podspec only, so CocoaPods will also run. `pod` is installed. | template pbxproj, pub cache |
| `xcodeproj` gem 1.27.0 and Maestro 2.11.0 are installed. `idb` is not. | `gem list`, `~/.maestro/bin/maestro` |
| `RepositoryProvider` in flutter_bloc 9.1.1 has a `dispose` callback. | pub cache source |
| Simulators: iPhone 17 Pro on iOS 26.5 (`2938F81B-D7F8-4DFD-81D8-968C25C04F1F`), iPhone 16e on iOS 18.6 (fallback-path check). | `xcrun simctl list` |
| Bundle ID `in.appamania.spinfolk`, org `in.appamania` (owner decision, recorded in spec line 237). Team ID not confirmed. | `docs/spec-v2.md` |

Versions seen in the local pub cache (hints only; the implementer resolves the real latest and pins exactly): flutter_bloc 9.1.1, get_it 9.3.0, injectable 3.0.0, injectable_generator 3.1.3, go_router 18.1.4, sqflite 2.4.5, shared_preferences 2.5.6, flutter_tts 4.2.5, build_runner 2.17.1, sqflite_common_ffi 2.4.5, material_ui 1.11.1, flutter_lints 6.0.0.

## 3. Scope

### Phase 0 — baseline
- Flutter app created in place at the repo root (iOS only, package `spinfolk`, org `in.appamania`), SDK pinned by FVM.
- Pinned dependencies exactly as spec A9, plus the template's own `material_ui`. `cupertino_icons` removed.
- iOS minimum 17.0, forced dark appearance, `FlutterDeepLinkingEnabled = NO`.
- DI skeleton (`lib/core/di/injection.dart` + committed generated config) with a `Random` module; router module with a single `/new` route; `SpinfolkApp`; colour/spacing/radius tokens.
- `tool/check_rules.sh` rule checker.
- One smoke test. README stack line corrected; superseded banner on `CLAUDE_HANDOFF.md`.

### Phase 1 — native glass proof
- Swift: `Glass.swift`, `PickerView.swift`, `ActionBarView.swift` under `ios/Runner/Native/`, factories registered in `AppDelegate`.
- Dart: `NativeIsland` (shared host + `NativeViewLink`), `NativePicker`, `NativeActionBar` — all `StatelessWidget`.
- `SetupCubit` (count 2–60 only), registered with injectable, provided app-wide.
- Temporary proof harness in `lib/dev/` (page, cubit, test painter, 10 s spin owner), wired as the `/new` route.
- Evidence: screenshots, Maestro run output, frame statistics.

## 4. Non-goals (do not build now)

- Session domain, SQLite schema, repositories, `SessionBloc`, `SettingsCubit`, `AppNavigator`, `bloc_listenable.dart`, redirects, other routes.
- `@preResolve` Database and SharedPreferences modules (added with their first consumer; `configureDependencies` stays synchronous until then).
- Names in `SetupCubit`, the real New Game screen, dial, bottle, role cards, Nunito font, app icon.
- Live Activity, widget target, `NativeBridge`, URL scheme, `NSSupportsLiveActivities`, speech.
- CI, TestFlight, signing, real-device runs, orientation lock, iPad tuning, Android.
- Any glass imitation in Flutter (`BackdropFilter`, shaders). If native sampling fails, stop and report.

## 5. Key decisions

Each: problem → options → pick.

**D1. Flutter patch version.** Options: 3.50.0 (was pinned), 3.50.1 (latest). Pick **3.50.1** — latest patch, templates identical, already installed. Global FVM default stays untouched.

**D2. Material import.** Options: deprecated `flutter/material.dart`; `material_ui` package. Pick **`package:material_ui/material_ui.dart`**, pinned exactly — it is what the 3.50 template generates and what the deprecation message names. It is one dependency beyond spec A9, covered by spec row A1-2 ("current recommended Material import"). Files that need no Material widgets import `package:flutter/widgets.dart`. Implementer re-confirms from the generated `lib/main.dart` before deleting it.

**D3. Per-view MethodChannel without a StatefulWidget.** The channel name contains the view id, which only arrives in `onPlatformViewCreated`, and config must be pushed on later rebuilds.
- (a) App-wide singleton controller per island kind: collides when two action bars coexist during a route transition.
- (b) Channel held by the page's cubit: leaks platform plumbing into presentation logic.
- (c) A tiny `NativeViewLink` object scoped to the island's own subtree through `RepositoryProvider(create:, dispose:)`.
Pick **(c)** — per-instance lifetime, automatic disposal, no state class, no new dependency. The island pushes its config from `build`, guarded by an equality check so the call is idempotent; the link re-sends the latest config on attach to close the race between first build and view creation.

**D4. Adding Swift files to the Xcode project.** Options: hand-edit `project.pbxproj`; one-shot `xcodeproj` Ruby command; put all Swift in `AppDelegate.swift`. Pick the **`xcodeproj` one-shot** (gem already installed, no script committed); hand-edit mirroring the `SceneDelegate.swift` entries is the fallback.

**D5. Factory registration point.** Options: `pluginRegistry.registrar(forPlugin:)`; `applicationRegistrar`. Pick **`engineBridge.applicationRegistrar`** inside `didInitializeImplicitFlutterEngine` — the API intended for app-level channels and views. `SceneDelegate` is untouched until Phase 4.

**D6. Swift sharing.** Options: generic hosting base class; fully separate files; separate files sharing one glass modifier. Pick **separate files + one shared `glassBackground` modifier** — two concrete islands do not justify a generic host; roughly 25 duplicated lines accepted.

**D7. Proof harness shape.** Options: reuse future `SpinStage`/`SessionBloc` names; throwaway code in `lib/dev/`. Pick **`lib/dev/`** with a temp `ProofCubit` — nothing in it survives Phase 2, so it must be trivially deletable. Only `SetupCubit` and the three `lib/platform/` files are permanent.

**D8. Interaction verification.** An agent cannot touch the simulator by hand. Options: owner-only manual check; XCUITest target (project surgery); Maestro flow. Pick **Maestro** (installed; drives native controls by accessibility text). If Maestro cannot drive this Xcode/simulator combination, those gate items are reported as NOT VERIFIED and handed to the owner — never assumed.

**D9. Jank measurement.** Profile and release builds do not run on simulators. Options: eyeball a video; in-app `FrameTiming` collection. Pick **`SchedulerBinding.addTimingsCallback`** in the temp cubit, shown on screen and captured by screenshot. Debug-on-simulator numbers are indicative only; a real-device profile run needs a signing team and is deferred.

**D10. When to add deps.** Spec Phase 0 says "add pinned deps". Pick **all A9 deps in Phase 0**, even those unused until Phase 3 — this proves the CocoaPods + SwiftPM build with every plugin before any feature depends on it.

## 6. Contracts fixed in these phases

Per-view channels (spec A7), names `spinfolk/picker/<viewId>` and `spinfolk/actionbar/<viewId>`, view types `spinfolk/picker` and `spinfolk/actionbar`, standard codecs.

| View | Creation params and `config` (Dart → iOS) | iOS → Dart |
|---|---|---|
| Picker | `{min: int, max: int, value: int}` | `changed {value: int}` |
| ActionBar | `{items: [{id, label, style: primary\|secondary\|destructive\|choice, enabled: bool}], layout: stack\|row}` | `tap {id: String}` |

Both sides validate what they receive: Swift ignores malformed config and clamps the picker value into `min...max`; Dart drops calls with the wrong shape, and `SetupCubit.countChanged` ignores values outside 2–60.

## 7. Acceptance checks

### Phase 0 gate
- P0-1 `fvm flutter --version` reports 3.50.1; `.fvmrc` says 3.50.1; global default unchanged.
- P0-2 `pubspec.yaml` has no `^` except the `environment.sdk` line; `pubspec.lock` present; only the planned packages appear as direct deps.
- P0-3 `fvm dart run build_runner build --delete-conflicting-outputs` succeeds and produces `lib/core/di/injection.config.dart` with `Random` and `GoRouter` registered.
- P0-4 `fvm dart format --set-exit-if-changed .` → exit 0. `fvm flutter analyze` → "No issues found!".
- P0-5 `fvm flutter test` passes (smoke test).
- P0-6 `tool/check_rules.sh` → exit 0.
- P0-7 `fvm flutter build ios --simulator --debug` succeeds; app installs and launches on the iOS 26.5 simulator; screenshot shows the dark baseline page with "Spinfolk".
- P0-8 Built `Info.plist`: bundle id `in.appamania.spinfolk`, `MinimumOSVersion` 17.0, `FlutterDeepLinkingEnabled` false, `UIUserInterfaceStyle` Dark.
- P0-9 `README.md` content preserved apart from the stack paragraph; `.gitignore` covers Flutter build output, `.fvm/`, and signing secrets.

### Phase 1 gate (spec wording in bold)
- P1-1 **Picker value reaches SetupCubit**: after a wheel swipe the Flutter text `Players: N` changes; tapping the destructive item sets the count to 2 from Dart and the wheel moves to 2 (proves both directions).
- P1-2 **Cubit state toggles native enabled**: tapping Spin makes the primary item read "Spinning…" and disabled for the spin, then "Spin" and enabled again, without the view being recreated.
- P1-3 **Glass samples Flutter content**: two screenshots taken mid-spin show the moving test pattern visibly through both glass shapes, and differing between the two shots. A flat grey or black card is a failure.
- P1-4 **No blocked touches**: native buttons, the native wheel, and a Flutter `GestureDetector` placed between the islands all respond in one Maestro run.
- P1-5 **No jank in the 10 s spin**: second run shows at least 570 frames and at most 2 frames over 33 ms. Numbers are reported verbatim either way.
- P1-6 **Reduce Transparency / Reduce Motion checked**: with each enabled, islands stay legible, the page shows `Reduce motion: on`, and the spin shortens to 600 ms. If the settings cannot be toggled from the CLI or Maestro, report NOT VERIFIED.
- P1-7 Fallback path: on the iOS 18.6 simulator the app launches and the islands render with `.ultraThinMaterial` in the same shapes (one screenshot).
- P1-8 All layout styles exercised: `primary`, `secondary`, `destructive` in `stack`; `choice` pair in `row`; switching layout does not recreate the view.
- P1-9 Format, analyze, tests (`setup_cubit_test`, `native_island_test`, smoke), `tool/check_rules.sh` all pass.
- P1-10 No retain cycle evidence: navigating is not available yet, so this is checked by code review of the `[weak self]` captures and `deinit` handler removal (listed in guidelines).

## 8. Risks

| Risk | Likelihood | Handling |
|---|---|---|
| Glass does not sample Flutter's Metal layer through the platform-view stack. | Low–medium; this is the reason for the phase. | Stop. Report with screenshots. Propose native layout options (for example one larger native region that owns its own backdrop content). Never fake glass. |
| Maestro's driver fails on Xcode 27.2 / iOS 26.5. | Medium | Try the iOS 26.4 simulator once; else mark P1-1/2/4 NOT VERIFIED and give the owner a 6-step manual script. |
| Accessibility toggles not settable from the CLI. | Medium | `defaults write com.apple.Accessibility …` first, then Maestro through Settings, then NOT VERIFIED. |
| `xcodeproj` gem rewrites the project file in a way Xcode 27 dislikes. | Low | Check `git diff`, build immediately; fallback is the hand edit. |
| Pub cannot resolve the spec's majors together (for example injectable 3.x with get_it 9.x). | Low | Stop and report the solver output; do not downgrade silently. |
| `flutter create` rejects org `in.appamania`. | Low | Create with `--org com.example`, then replace `PRODUCT_BUNDLE_IDENTIFIER` values; report it. |
| Debug-mode simulator frame times misjudge real performance. | Certain, small | Documented caveat; device profile run deferred until a team ID exists. |
| `UIHostingController` not parented to a view controller misbehaves (wheel not updating, safe-area insets). | Low | `safeAreaRegions = []` set up front; if needed, add the host as a child of the window's root view controller and remove it in `deinit`. |
| Glass shadow or highlight clipped at the platform-view rect. | Medium, cosmetic | Inset the shape 4–8 pt natively; do not clip in Flutter. |
| Fixed native heights clip text at large Dynamic Type sizes. | Medium | Out of gate for Phase 1 (clamped at `.accessibility2`); carried to Phase 2's largest-text gate. |
| Side effect in `build` (config push) flagged in review. | Low | Deliberate (D3); idempotent by equality guard; covered by `native_island_test`. |

## 9. Open questions

None block the work. Decided defaults, for the owner to overrule:

1. **`material_ui` as a direct dependency** — required by the 3.50 template; added and pinned.
2. **Evidence screenshots committed** under `docs/plans/phase-0-1/evidence/` (about 6 PNGs). Say so if they should stay out of git.
3. **Orientation and iPad** left at template defaults (portrait + landscape, device family 1,2). The spec is silent; a portrait lock would be a two-line Info.plist change in Phase 2.
4. **Real-device jank check** deferred until an Apple team ID is confirmed.
5. **Branching** — work on branch `phase-0-1`; no push and no commit unless the owner or orchestrator asks.
