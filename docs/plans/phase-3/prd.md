# Spinfolk — Phase 3 (persistence lifecycle, prefs, native speech): Technical PRD

Date: 2026-11-22 · Spec: `docs/spec-v2.md` (authoritative; architecture fixed) · Builds on: `docs/plans/phase-2/` (contract) **and Phase 2b "Flow v2 · History"** (planned separately, lands first) · Companion: `guidelines.md` in this folder · Branch: `phase-3`, cut from the **`phase-2b` head**.

## 1. Problem

After Phase 2 the game loop is complete and stored in SQLite, but four spec items are still open:

- Nothing dispatches `AppBackgrounded`, so a spin interrupted by backgrounding only settles when the stage is rebuilt.
- There are no preferences, no `SettingsCubit`, and the Session sheet has no Voice section.
- Nothing speaks. `speechLine()` is shown as text only, `ReplayRequested` bumps `replayCount` but no button and no listener exist.
- `flutter_tts` is gone (owner decision), so speech must be a native `AVSpeechSynthesizer` behind the shared `spinfolk/native` MethodChannel, which does not exist yet on either side.

Phase 3 closes those four. The Live Activity, `url.open` and the widget target are Phase 4.

### Dependency: Phase 2b lands first

Phase 2b (branch `phase-2b`, not planned here) adds the Home hub as the root route, history and round-log tables (schema version 2), the end summary, flick-to-spin, quick counts, and `adaptive_platform_ui 1.0.2` glass widgets. This plan was written against the Phase 2 code (`e425351`) before 2b existed. What Phase 3 needs from 2b, and how it adapts:

| Phase 2b change | Effect on Phase 3 |
|---|---|
| Root route is Home, not `/new`; Resume may live on Home instead of `/resume`. | No Phase 3 logic depends on routes. Only the widget-test harness entry steps and the deferred Maestro flows follow 2b's path to a running game. |
| Schema v2 (history, round log). End Session saves to History and shows a summary. | Phase 3 does not touch the schema or the repository. "Session ended" for the Announcer means *the bloc no longer exposes an active session*, whatever 2b calls that state. The deferred "End clears DB" check becomes "End removes the active session, keeps history and prefs". |
| `SessionBloc` gets new events, state fields or states (round log, summary). | `liveReveal` (D2) is one more field on the active state; it must be `false` in every state 2b emits except the one for `SpinAnimationFinished`. |
| Flick-to-spin fires the same `SpinRequested`. | None. |
| Session sheet may be restyled (detents, adaptive widgets). | The VOICE section is added to whatever sheet 2b leaves, using **`AdaptiveSwitch` / `AdaptiveSlider`** when `adaptive_platform_ui` is in `pubspec.yaml`, else Material `Switch` / `Slider` (D14). |
| 2b may already own an `AppLifecycleListener` (purge soft-deleted history on background). | Add `onHide → AppBackgrounded` to that listener; do not create a second one (D9). |

If 2b renamed a symbol this plan names, follow the code and say so in the report. If 2b changed a *behaviour* this plan relies on (listed in `guidelines.md` §0), stop and report before building.

## 2. Verified facts (checked 2026-11-22, not assumed)

| Fact | Source |
|---|---|
| Phase 2 is committed as `e425351` on branch `phase-2`. `SessionBloc` handles `AppBackgrounded` and `ReplayRequested` exactly as the Phase 2 contract says; `SpinAnimationFinished` and `AppBackgrounded` share `_finishSpin` and emit **identical** states. | `lib/features/session/presentation/bloc/session_bloc.dart` |
| `SpinStage` stops the spin controller when the state stops spinning, and fires the haptic and `SpinAnimationFinished` only from the controller's `completed` status. | `lib/features/game/presentation/widgets/spin_stage.dart` |
| `GamePage` already drops its native bars while a sheet or dialog covers it (the D12 fallback was taken). | `lib/features/game/presentation/pages/game_page.dart` |
| `shared_preferences 2.5.6` is already pinned. `SharedPreferencesWithCache.create(cacheOptions: SharedPreferencesWithCacheOptions(allowList: …))`; typed getters throw `ArgumentError` for a key outside the allow list. `setMockInitialValues` mocks only the legacy store, **not** the async platform that `SharedPreferencesWithCache` uses. | `shared_preferences-2.5.6/lib/src/shared_preferences_{async,legacy}.dart` |
| `RepositoryProvider` (flutter_bloc 9.1.1) takes `create`, `dispose`, `lazy`. The codebase already uses it to own a non-widget object (`NativeViewLink`). | `flutter_bloc-9.1.1/lib/src/repository_provider.dart`, `lib/platform/native_island.dart` |
| iOS registration happens in `AppDelegate.didInitializeImplicitFlutterEngine`; `engineBridge.applicationRegistrar.messenger()` is the binary messenger. The project uses explicit file references (objectVersion 54), so new Swift files must be added to the target; the `xcodeproj` gem 1.27.0 is installed and was used for that in Phase 1. | `ios/Runner/AppDelegate.swift`, `ios/Runner.xcodeproj/project.pbxproj`, `gem list xcodeproj` |
| The Swift in `guidelines.md` §3 (`SpeechBridge`, `NativeChannel`) compiles for the simulator with Xcode 27.2 / Flutter 3.50.1. Compiled in a scratch copy of the repo, not in the repo. Runtime behaviour is **not** verified. | `fvm flutter build ios --simulator --debug` → `✓ Built build/ios/iphonesimulator/Runner.app` |
| Artboards: the announcement row is speaker icon + quoted line + a 36-pt "Replay" capsule (`Revealed`, `Challenge`). `Crowd60` shows the notice "Voice unavailable. Read the roles aloud." **in place of** that row. The sheet's VOICE section is first: Announcements switch, Voice row ("Samantha (Enhanced) ›"), Speed slider with a "Normal" label, Preview "Play sample", footnote "Only voices already on this iPhone are listed. Nothing downloads." | `docs/design/project/{Revealed,Challenge,Crowd60,Settings}.dc.html` |
| No artboard exists for a voice list (also none in Flow v2). | `docs/design/project/` |
| `adaptive_platform_ui 1.0.2`: `AdaptiveSwitch({value, onChanged, activeColor, thumbColor})`, `AdaptiveSlider({value, onChanged, onChangeStart, onChangeEnd, min, max, divisions, label, activeColor, thumbColor})`. On iOS 26+ both are native platform views (`UiKitView`); below that `CupertinoSwitch` / Cupertino slider. Value-in, callback-out — same shape as the Material widgets. | `adaptive_platform_ui-1.0.2/lib/src/widgets/adaptive_{switch,slider}.dart` |
| Flow v2 interaction spec: reveal order is stop → haptic → pulse → role cards → **announcement**; sheets "pause nothing"; errors use the `.error` notification haptic. | `docs/design/project/Interactions.dc.html` |

## 3. Scope

### In
- **Prefs**: `Prefs` (announce, voiceId, rate), `Voice`, `PrefsRepository` contract, `PrefsRepositoryImpl` on `SharedPreferencesWithCache` (allow list `announce`, `voiceId`, `rate`), DI `@preResolve`.
- **`SettingsCubit`** (singleton): prefs, voice list, inline voice picker state, save failure.
- **Native channel `spinfolk/native`**, speech part only: `speech.speak {text, voiceId?, rate}`, `speech.stop`, `speech.voices {language}` → `[{id,name,language,quality}]`, iOS→Dart `speech.event {state: done|cancelled|error}`. Dart `NativeBridge`, Swift `NativeChannel` + `SpeechBridge`.
- **`Announcer`** (singleton, started in `main`): speaks after a live reveal when Announcements is on, speaks on Replay, owns the "voice unavailable" notice.
- **Lifecycle**: `AppLifecycleListener.onHide` → `AppBackgrounded`.
- **UI**: Replay row on Revealed and Challenge, voice notice, VOICE section in the Session sheet.
- **One state field**: `SessionActive.liveReveal` (D2).
- **Tests** for all of the above; two rule lines in `tool/check_rules.sh`.
- **Deferred device flows** written but not run: `tool/maestro/phase3.yaml`, `tool/phase3_gate.sh`.

### Deferred to Phase 4 (not stubbed, not registered, no placeholder UI)
`activity.*` methods, `url.open` / `url.ready`, `LiveActivitySync`, `SceneDelegate` URL handling, URL scheme, `NSSupportsLiveActivities`, widget target, Live Activity status line in the sheet.

## 4. Non-goals

- No new dependency beyond what Phase 2b added (no `flutter_tts`, no `shared_preferences_platform_interface` as a direct dependency, no `mocktail`).
- No Podfile. No microphone permission, no `UIBackgroundModes`, no change to `Info.plist` in this phase.
- No new route. No voice download UI. No speech queue, no retry loop, no speech while backgrounded.
- No change to the SQLite schema, the history tables or `SessionRepository`. No planning or rework of Phase 2b features.
- No simulator or Maestro run in this phase (owner decision); no evidence files are committed (`docs/plans/*/evidence/` is git-ignored).

## 5. Key decisions

Each: problem → options → pick.

**D1. Who owns `spinfolk/native` in Dart.** One MethodChannel can have one Dart handler, and both `speech.event` (now) and `url.open` (Phase 4) arrive on it. Options: `Announcer` owns the channel now and Phase 4 moves it; a `NativeBridge` class now, extended in Phase 4. Pick **`NativeBridge` now** (`lib/platform/native_bridge.dart`, spec A9 path) — Phase 2's plan placed it in Phase 4, but speech cannot exist without it. Phase 4 only adds methods.

**D2. Telling a live reveal from a backgrounded or restored one.** The spec forbids speaking for `AppBackgrounded` and for restores, but both spin endings emit the same state. Options: (a) Announcer checks `lifecycleState` when the reveal arrives — timing dependent, hard to test; (b) a `BlocObserver` that sees events — global machinery for one rule; (c) one explicit state bit. Pick **(c): `SessionActive.liveReveal`**, `true` only in the state emitted for `SpinAnimationFinished`, `false` everywhere else (every other emit already rebuilds the state explicitly). Deterministic, six lines, unit-testable.

**D3. Where the voice notice lives.** Options: a new `SessionBloc` event and field (couples storage state to audio); `SettingsCubit`; the `Announcer` itself as a tiny cubit. Pick **`Announcer extends Cubit<bool>`** (`true` = show "Voice unavailable. Read the roles aloud."). The game page and the sheet read it with `BlocBuilder`. `SessionBloc`'s event list stays as the spec lists it.

**D4. Where the Announcer gets prefs.** Options: `PrefsRepository.load()`; `SettingsCubit.state.prefs`. Pick **`SettingsCubit.state.prefs`** — "Play sample" must use the slider value before it is committed, and a failed save must still apply for the running session. The spec already makes platform services talk to `SettingsCubit` (A8).

**D5. Voice picker without a route.** No artboard, fixed route list. Options: a new route (not allowed); `?voice=1` on the sheet route (re-runs the sheet transition); an inline expandable list inside the VOICE card. Pick **inline list**, open/closed bit in `SettingsState`. First entry "Default" (`voiceId = null`), then voices sorted premium → enhanced → standard, then by name.

**D6. Speech rate.** `AVSpeechUtterance.rate` runs 0…1 with 0.5 as normal; the ends are unusable. Pick: the stored `rate` **is** the AVSpeech rate, limited to **0.35 … 0.65**, default 0.5 (spec). The slider spans that range; label "Slow" below 0.45, "Fast" above 0.55, else "Normal". The three numbers are named constants in `Prefs` so tuning on a real device is a one-line change.

**D7. When prefs are written.** Options: every slider tick; on change end. Pick: switch and voice save at once; the slider emits on every tick and **saves on `onChangeEnd`**. Saves are optimistic: the new value is emitted first; a failed write keeps it for the session and sets `failure` (shown inline in the sheet).

**D8. Voice list refresh.** Options: once at start; on every sheet open. Pick **on sheet open** — the settings button already forwards intent, so it calls `settings.opened()` then `nav.settings()` (same shape as `namesOpened(); nav.names()`). A voice installed in iOS Settings shows up without a relaunch.

**D9. Lifecycle hook without a `StatefulWidget`.** If Phase 2b already created an `AppLifecycleListener`, extend it. Otherwise — options: a top-level object in `main`; a `RepositoryProvider<AppLifecycleListener>(lazy: false, dispose: …)` in `app.dart`. Pick the **provider** — the pattern already exists in the codebase, it is disposed with the tree, and widget tests exercise it through `pumpApp`. `onHide` (not `onInactive`): Control Centre or a system alert must not cut a spin short.

**D10. Stop on background, native side.** Dart may be suspended before it can react. `SpeechBridge` observes `UIApplication.didEnterBackgroundNotification` itself and stops; that reports `cancelled`, which shows no notice.

**D11. Event mapping.** `done` = finished; `cancelled` = stopped by us (`speech.stop`, replacement, background); `error` = audio-session interruption began while speaking. A failed `speech.speak` call (audio session could not start, empty text, channel missing) is a failed method call, not an event. Dart treats a failed call and `error` the same: notice on. A replaced utterance reports nothing (the native side ignores callbacks for anything but the current utterance).

**D12. What cancels speech from Dart.** The round number changing (Pass / Next Round) or the session ending → `speech.stop` and notice off. Choosing Truth or Dare does **not** cut the reveal line off.

**D13. `PrefsRepositoryImpl` is not unit-tested on the host.** The in-memory async store lives in a transitive package that may not be imported directly (lint, and no new dependencies). Pick: all validation sits in the pure `Prefs.sanitized`, which is tested; the implementation is a pass-through of six calls; persistence across a kill is a deferred device check.

**D14. Switch and slider widgets.** Phase 2b brings `adaptive_platform_ui` for native glass controls. Options: Material widgets regardless; adaptive widgets when the package is present. Pick **adaptive when present**: `AdaptiveSwitch(value, onChanged, activeColor: taker)` and `AdaptiveSlider(value, min, max, onChanged, onChangeEnd, activeColor: taker)`. The cubit API (D7) is widget-agnostic, and both adaptive widgets have the exact callbacks it needs. They are platform views on iOS 26, so nothing Flutter-drawn may overlap them and they are never wrapped in `Opacity`, `ClipRRect` or a transform (same rule as the two islands). Tests drive them through their `onChanged` / `onChangeEnd` callbacks, never by gesture, so the test is the same for either widget family.

## 6. Contracts fixed in this phase

**Channel `spinfolk/native`, speech part** (owner decision, verbatim):

| Direction | Method | Args | Result |
|---|---|---|---|
| Dart → iOS | `speech.speak` | `{text: String, voiceId: String?, rate: double}` | `null`; `FlutterError(code: "speech")` when the audio session cannot start or text is empty |
| Dart → iOS | `speech.stop` | — | `null` |
| Dart → iOS | `speech.voices` | `{language: String}` (BCP-47 prefix, e.g. `en`) | `[{id, name, language, quality}]`, quality ∈ `default` / `enhanced` / `premium` |
| iOS → Dart | `speech.event` | `{state: "done" / "cancelled" / "error"}` | — |

Audio session: `.playback`, options `.mixWithOthers` + `.duckOthers`, activated in `speech.speak`, deactivated with `.notifyOthersOnDeactivation` after the utterance ends.

**Preferences** (never touched by End Session): `announce` bool `true` · `voiceId` String? `null` · `rate` double `0.5`.

**State**: `SessionActive` gains `bool liveReveal` (default `false`, part of `==` / `hashCode`).

**Announcer rules**
| Trigger | Action |
|---|---|
| state with `liveReveal == true` and `prefs.announce` | speak `speechLine(session)` |
| `replayCount` increased, same session | speak `speechLine(session)` (ignores `announce`) |
| round changed, or state is no longer `SessionActive` | `speech.stop`, notice off |
| `speech.speak` failed, or `speech.event error` | notice on |
| a later `speech.speak` succeeded | notice off |
| anything else (`ResumeConfirmed`, `AppBackgrounded` reveal, `ModeChosen`, failures) | nothing |

**Semantics labels for the deferred flows**: Replay button — "Replay announcement"; switch row — "Announcements"; "Play sample" button text as written.

## 7. Acceptance checks

Static (run in this phase, real output pasted)
- P3-1 `fvm dart run build_runner build --delete-conflicting-outputs` succeeds; generated config additionally registers `SharedPreferencesWithCache` (pre-resolved), `PrefsRepository`, `SettingsCubit`, `NativeBridge`, `Announcer`.
- P3-2 `fvm dart format --set-exit-if-changed .` exit 0; `fvm flutter analyze` "No issues found!".
- P3-3 `fvm flutter test` passes, including the four new files and the extended ones.
- P3-4 `tool/check_rules.sh` → `check_rules: OK`, with Phase 2b's rules intact and the two new rules (no `flutter_tts`; no microphone key or background modes in `Info.plist`).
- P3-5 `fvm flutter build ios --simulator --debug` succeeds with the two new Swift files in the Runner target.
- P3-6 `git diff phase-2b -- pubspec.yaml pubspec.lock ios/Runner/Info.plist` is empty; no `ios/Podfile`.

Behaviour proven by tests
- P3-7 Bloc: `liveReveal` is `true` only in the state after `SpinAnimationFinished`; `false` after `AppBackgrounded`, `ResumeConfirmed`, and every later event.
- P3-8 Announcer: live reveal speaks once with the exact `speechLine` and the stored voice and rate; backgrounded reveal and resumed session do not speak; Announcements off → no automatic line, Replay still speaks; Replay in Challenge speaks the mode line; failed call and `error` event raise the notice; `cancelled` and `done` do not; next round and End send `speech.stop` and clear the notice.
- P3-9 Prefs: defaults; rate clamped to 0.35…0.65 and non-finite → 0.5; empty `voiceId` → null.
- P3-10 `SettingsCubit`: loads stored prefs at construction; each change is emitted and saved (slider only on commit); failed save keeps the value and sets `failure`; `opened()` fills and sorts voices; selecting a voice closes the list.
- P3-11 `NativeBridge`: argument maps match §6; `speak` returns `false` on `PlatformException` and `MissingPluginException`; malformed voice entries are dropped; unknown `speech.event` states are ignored.
- P3-12 Widget flow: hiding the app mid-spin lands on Revealed with no `speech.speak`; Replay row present on Revealed and Challenge; notice replaces the row; sheet toggles reach the fake prefs store; End Session leaves prefs untouched.
- P3-13 Layout: no overflow at 375 × 667 with scales 1.0 / 1.35 / 3.12 and at 320 × 568 for the sheet with the VOICE section (voice list open, 12 voices), Revealed with the Replay row, and Revealed with the notice.

Deferred to the post-Phase-5 device pass (flows written now, **NOT VERIFIED** in this phase)
- P3-D1 Prefs persist across a kill and relaunch.
- P3-D2 Kill mid-spin → Resume → completed reveal, same roles, no speech.
- P3-D3 Background mid-spin and return → revealed, no speech, no haptic.
- P3-D4 End Session removes the active session, keeps history (Phase 2b) and prefs.
- P3-D5 Corrupt active-session row (`DELETE FROM player WHERE seat = 1`, table names re-checked against schema v2) → notice + clean start screen.
- P3-D6 Audible line with the mute switch on; other audio ducks and comes back; an interruption shows the notice; voices listed match iOS Settings. (Real device.)
- P3-D7 Sheet with the adaptive switch and slider scrolls and dismisses cleanly; controls respond on the first touch.

## 8. Risks

| Risk | Likelihood | Handling |
|---|---|---|
| `setActive(false)` right after the utterance fails as "busy", leaving music ducked. | Medium | Deactivation is delayed by a named constant (`deactivateDelay`, 0.3 s) and skipped if a new line started. Tune in P3-D6. |
| Dart does not get to process `onHide` before suspension; the spin then completes on resume and speaks. | Low | Accepted: the line is spoken once, on return. Reported if seen in P3-D3. |
| `SharedPreferencesWithCache.create` throws at start → app stays on the launch screen. | Very low | Not guarded (a fallback store would be a second implementation). Reported if it ever happens. |
| Widget tests now see a missing native channel and show the notice everywhere. | Certain unless handled | The harness installs a mock handler for `spinfolk/native` by default. |
| Phase 2b reshapes files this plan edits (`session_state.dart`, `game_page.dart`, the sheet, `app.dart`, the test harness). | High | `guidelines.md` §0 is a reconcile checklist run before any edit; edits are described by anchor (what to add next to what), not by line. New files (`prefs`, `settings_cubit`, `native_bridge`, `announcer`, Swift) do not depend on 2b. |
| An adaptive switch or slider (platform view) inside a scrolling sheet jitters or swallows the sheet's drag. | Low–medium | Deferred device check P3-D7. Fallback: Material `Switch` / `Slider` for those two controls only; report it. |
| Speech verified only by compile until the device pass. | Certain | Stated in the report as NOT VERIFIED; the Swift is small and isolated in one file. |

## 9. Open questions

None block the work; the default is built unless the owner says otherwise.

1. **Voice language.** Spec: voices filtered to the *device* language. All spoken lines are English, so on a non-English phone the list (and the default voice) will be non-English voices reading English. Default: follow the spec. Alternative: always `en`.
2. **Mode line.** Spec speaks automatically only after a live reveal. The Challenge artboard shows "Player 7 chose Truth." with the speaker icon. Default: not spoken automatically; Replay on Challenge speaks it.
3. **Rate range** 0.35 … 0.65 (D6) is a judgement, to be tuned by ear on a device.
4. **Re-validation.** This plan predates the Phase 2b plan and code. Once 2b is merged, a ten-minute read of §0 of the guidelines against the real code is advised before the implementer starts; no redesign is expected.

## Owner decisions (2026-11-22) — do not reopen
- All open-question defaults in this PRD approved as written.
- Glass: adaptive_platform_ui IOS26Button for the 5 chrome buttons (accept its medium haptic); cards/toast/confirm cards solid.
- History swipe: full-swipe Dismissible delete + undo toast (no resting Delete button).
- Zero-round games are not saved to History.
- Voices follow device language; mode line spoken only on Replay; player names shown on Lock Screen; after a pass the Live Activity shows no roles.
- Evidence screenshots stay out of git; simulator/Maestro automation runs once after all phases.
