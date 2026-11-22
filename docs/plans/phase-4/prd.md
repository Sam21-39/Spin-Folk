# Spinfolk — Phase 4 (Live Activity + Dynamic Island): Technical PRD

Date: 2026-11-22 · Spec: `docs/spec-v2.md` A7, A8 (authoritative; architecture fixed) · Builds on: `docs/plans/phase-3/` and Phase 2b "Flow v2 · History" · Companion: `guidelines.md` in this folder · Branch: `phase-4`, cut from the `phase-3` head.

## 1. Problem

After Phase 3 the shared `spinfolk/native` channel exists and carries speech only. The app has no Live Activity, no widget extension target, no URL scheme, and nothing dispatches `SessionLinkOpened`.

Phase 4 delivers, with no package and no App Group:

- a Lock Screen Live Activity and Dynamic Island for the running session, updated only at the moments the spec allows (never at spin start);
- a tap on it returning to the saved session, cold or warm;
- clean-up of stale, duplicate and foreign activities at launch and on foreground;
- one quiet line in the Session sheet when Live Activities are off.

### Dependencies

| From | What Phase 4 uses |
|---|---|
| Phase 3 | `NativeBridge` (Dart) and `NativeChannel` (Swift) — Phase 4 only adds methods. `SettingsCubit` gets one field. The lifecycle listener in `app.dart` gets `onResume`. `FakeNative` test support. |
| Phase 2b — round log | The Live Activity's "Last round" content. In phase `ready` the session row has no roles; the last completed round comes from the round log **through bloc state** (the same value the Ready screen's "LAST P3 → P7 · Truth" line shows). `LiveActivitySync` never queries the database. |
| Phase 2b — Home hub | The root route is Home, not `/new`. A Live Activity tap on a cold start must end on the game screen, so a matching `SessionLinkOpened` has to behave like Home's "Resume game". |
| Phase 2b — end summary, "new game ends the current one" | "Session ended" = the bloc stops exposing an active session, or the session id changes. The activity ends with "Session ended · N rounds". |
| Phase 2b — schema v2 | Nothing in Phase 4 reads or writes the database. `sessionId`, `startedAt` and the round number come from the `Session` entity. |
| Phase 2b — `adaptive_platform_ui` | None. It is a Flutter plugin linked into Runner only; the widget extension links no Flutter code. |

This plan was written before Phase 2b and Phase 3 existed as code. `guidelines.md` §0 is a reconcile checklist to run first.

## 2. Verified facts (checked 2026-11-22, not assumed)

| Fact | Source |
|---|---|
| `ios/Runner.xcodeproj`: objectVersion 54, targets `Runner` and `RunnerTests`, configurations Debug / Release / Profile, deployment target 17.0, one local SwiftPM package reference (`FlutterGeneratedPluginSwiftPackage`), no Podfile, no `DEVELOPMENT_TEAM`. Runner phases: Run Script → Sources → Frameworks → Resources → Embed Frameworks → Thin Binary. Flutter xcconfigs are set as base configuration at **target** level only. | `project.pbxproj` |
| `xcodeproj` gem 1.27.0 is installed (Ruby 3.2.0). Its `Project#new_target` adds a `Foundation.framework` reference and a Resources phase, and only derives Debug/Release settings. | `gem list`, `xcodeproj-1.27.0/lib/xcodeproj/project/project_helper.rb` |
| The script in `guidelines.md` §3 was run on a scratch copy of the repo: it adds the `SpinfolkWidget` app-extension target, keeps the SwiftPM reference intact, is idempotent, and leaves Runner's phases as `… Embed Frameworks > Embed Foundation Extensions > Thin Binary`. | scratch run, script output |
| With that target, the Swift of `guidelines.md` §2 and the plist keys of §1, `fvm flutter build ios --simulator --debug` succeeds (Xcode 27.2, Flutter 3.50.1): no build cycle; `Runner.app/PlugIns/SpinfolkWidget.appex` present; app and extension both `0.1.0` / `1`, both `MinimumOSVersion 17.0`; extension id `in.appamania.spinfolk.SpinfolkWidget`; signature ad hoc, `TeamIdentifier=not set`; `NSExtensionPointIdentifier = com.apple.widgetkit-extension`; `grep -c DEVELOPMENT_TEAM project.pbxproj` → 0. **Compile and bundle only — nothing was launched; runtime behaviour is not verified.** | scratch build, `PlistBuddy`, `codesign -dv` |
| `FlutterSceneDelegate` implements `scene:willConnectToSession:options:` and `scene:openURLContexts:`, so a Swift subclass can `override` them and call `super`. | `nm` on `Flutter.framework` (simulator slice) |
| The app uses the implicit engine and the UIScene life cycle (`SceneDelegate: FlutterSceneDelegate`, `UISceneDelegateClassName` in `Info.plist`). `FlutterDeepLinkingEnabled` is already `false`. | `ios/Runner/{AppDelegate,SceneDelegate}.swift`, `Info.plist` |
| Canvas: Lock Screen = header (mark, "Spinfolk", "Round 12 · 8 players"), two role tiles TAKER / GIVER (role colour at 14 % as tile fill), footer "Last round: Truth · Tap to return to the game"; a second, one-line card "Session ready · 8 players / No rounds yet. Open to spin."; background `rgba(20,32,54,0.92)`, "system-tinted". Compact: mark leading, `3 › 7` trailing (giver coral, taker teal), accessibility "Round 12, Player 3 gives to Player 7". Minimal: mark. Expanded: mark + "Round 12", "8 players", GIVER → TAKER, "Truth · Tap to return". Ended: "Session ended · 12 rounds", `.immediate`. Disabled: "Lock Screen updates are off in iOS Settings." | `docs/design/project/LiveActivity.dc.html` |
| Flow v2: Ready shows "LAST P3 → P7 · Truth"; a passed round is logged as "Passed · no penalty" without roles; End shows a summary and "the Live Activity ends with 'Session ended · 12 rounds'"; starting a new game while one is in progress ends and saves the current one. | `Ready2`, `RoundLog`, `Interactions`, `UserFlow` artboards |

## 3. Scope

### In
- **Native, Runner**: `SpinfolkAttributes.swift` (member of both targets), `LiveActivityBridge.swift`, `activity.sync` / `activity.end` / `activity.reconcile` and `url.ready` / `url.open` on `NativeChannel`, `SceneDelegate` URL handling (cold + warm, queued until Dart is ready).
- **Native, new target `SpinfolkWidget`** (`in.appamania.spinfolk.SpinfolkWidget`, iOS 17.0, SwiftUI): `SpinfolkLiveActivity.swift`, `Info.plist`. Added and embedded by `tool/add_widget_target.rb`, no Xcode GUI.
- **`Info.plist` (Runner)**: `NSSupportsLiveActivities = YES`, URL scheme `spinfolk`.
- **Dart**: `NativeBridge` additions, `LiveActivitySync` (singleton, started in `main`), `SettingsCubit.activityStatus`, the status line in the sheet, `onResume` wiring, dispatch of `SessionLinkOpened`.
- **Tests** for the Dart side; one rule line in `tool/check_rules.sh`.
- **Deferred device flows** written but not run: `tool/maestro/phase4.yaml`, `tool/phase4_gate.sh`.

### Out
Push-driven updates, App Group, shared storage, home-screen widgets, interactive buttons (App Intents) in the activity, Apple Watch, iPad-specific layouts, signing and TestFlight (Phase 5).

## 4. Non-goals

- No live-activities package, no new Dart or Swift dependency, no Podfile.
- No `DEVELOPMENT_TEAM`, provisioning profile or entitlements file in the repo. Live Activities without push need no entitlement.
- No `UIBackgroundModes`, no background restart of an expired activity.
- No glass imitation and no `.glassEffect` in the widget: the Lock Screen surface is system-tinted (`activityBackgroundTint`), the island's capsule is drawn by iOS.
- No raw URL ever reaches `go_router`.
- No simulator or Maestro run in this phase (owner decision); no evidence files committed.

## 5. Key decisions

Each: problem → options → pick.

**D1. Adding the target without Xcode.** Options: hand-edit `project.pbxproj` (about 120 lines, error-prone); `Project#new_target` (adds a framework reference and a phase we do not want, misses Profile settings); a small script that builds the target object by object. Pick **the script** `tool/add_widget_target.rb` — deterministic, idempotent, reviewed as code, and already proven on a copy.

**D2. Extension version numbers.** App Store validation requires the extension's version to equal the app's, and Flutter owns those numbers. Options: hard-code; copy at build time with a script phase; reuse Flutter's xcconfig. Pick **the same base xcconfig as Runner** per configuration, with `MARKETING_VERSION = $(FLUTTER_BUILD_NAME)` and `CURRENT_PROJECT_VERSION = $(FLUTTER_BUILD_NUMBER)`. Verified equal in the built bundle.

**D3. Embed phase position.** Flutter's "Thin Binary" script and an extension copy phase after it form a build cycle. Pick: "Embed Foundation Extensions" is inserted **directly before "Thin Binary"**. Verified: no cycle.

**D4. Signing.** Team ID is not confirmed. Pick: `CODE_SIGN_STYLE = Automatic`, **no team anywhere**. Simulator builds sign ad hoc (verified). Device and archive builds stay blocked until the owner supplies the team (Phase 5); nothing in this phase needs it.

**D5. Where URL handling lives.** Options: (a) override the two scene methods in `SceneDelegate` and call `super` (spec wording); (b) register a `FlutterSceneLifeCycleDelegate` through a plugin registrar. Pick **(a)** — the superclass methods exist (verified), `super` keeps Flutter's own handling intact, and the spec names `SceneDelegate`.

**D6. "Queue until Dart registers its handler."** iOS cannot observe a Dart handler. Options: retry on `notImplemented` (no trigger to retry); Dart pulls an initial link; Dart announces readiness. Pick **`url.ready`** (Dart → iOS, no arguments): until it arrives the last link is held; on arrival it is delivered as a normal `url.open`. One delivery path. This is one method more than the A7 table lists.

**D7. Validating the link.** The URL is external input. Three checks: Swift accepts only `spinfolk://session/<32 lowercase hex>`; `NativeBridge` re-checks the id pattern; the bloc compares with the stored id and ignores mismatches. Nothing else from the URL is used.

**D8. When to sync.** A8 lists five triggers. Options: detect each transition; or one rule. Pick **one rule: sync when the payload changed and the state is not spinning.** The payload is a pure function of the session (plus the last logged round); it changes exactly on session start, reveal, mode chosen, round advanced and players edited, and it cannot change on replay, failures or speech. While spinning nothing is sent, so the Lock Screen never spoils the result. The reveal after `AppBackgrounded` syncs as well.

**D9. Ordering of native calls.** `sync`, `end` and `reconcile` are asynchronous and must not overtake each other. Pick a **serial future chain** inside `LiveActivitySync` (stdlib; no queue class).

**D10. Activity lifetime.** Spec: at most 8 h, `staleDate = start + 8 h`, restart on foreground if allowed. A session resumed the next day would otherwise request an activity that is already stale. Pick: `staleDate = request time + 8 h`; updates keep the activity's own `staleDate`; an activity that is stale or past its date is ended, and `sync` requests a fresh one (possible only in the foreground — in the background the request fails and reports `error`, which shows nothing).

**D11. "Last round" content (Phase 2b round log).** In phase `ready` the payload carries the last logged round's taker, giver, labels and mode when that round ended with Truth or Dare. If it was passed, or there is none, no roles are sent and the activity shows the one-line card. The widget tells "current" from "last" by `phase == "ready"`. The A7 argument list is unchanged.

**D12. Seat numbers.** `taker` / `giver` on the wire and `takerSeat` / `giverSeat` in `ContentState` are **0-based**, like everywhere else; the widget displays `seat + 1`. Labels come from `displayLabel` (the one label function).

**D13. Status reporting.** `sync` returns `active` / `disabled` / `unsupported` / `error`. `LiveActivitySync` passes it to `SettingsCubit`; the sheet shows "Lock Screen updates are off in iOS Settings." for `disabled` and `unsupported`, nothing for `error`. Gameplay never waits on any of it. iOS 17+ always has ActivityKit, so the Swift side never returns `unsupported`; Dart maps a missing channel to it.

**D14. Lifecycle.** The one `AppLifecycleListener` (Phase 3, in `app.dart`) gets `onResume → LiveActivitySync.foreground()`. `foreground()` = reconcile against the current session id, then force a sync. `start()` runs it once at launch.

**D15. Widget drawing.** The mark is drawn with SwiftUI shapes from the canvas geometry (no asset catalog in the extension, no image files). Text uses `.fontDesign(.rounded)`. Colours are the canvas tokens.

## 6. Contracts

**Channel `spinfolk/native`, added in this phase**

| Direction | Method | Args | Result |
|---|---|---|---|
| Dart → iOS | `activity.sync` | `{sessionId, startedAt (ms), players, round, phase, taker?, giver?, mode?, takerLabel?, giverLabel?}` | `{state: "active" / "disabled" / "error", message?}`. Starts an activity if none is live for the session, else updates. Ends duplicates, expired ones and other sessions' activities. |
| Dart → iOS | `activity.end` | `{sessionId, rounds}` | `{ok: bool}` — final content `ended = true`, `round = rounds`, dismissal `.immediate` |
| Dart → iOS | `activity.reconcile` | `{sessionId?}` | `{ended: int}` — ends every activity whose session differs, duplicates and expired ones; all when null |
| Dart → iOS | `url.ready` | — | `null`; flushes a held link |
| iOS → Dart | `url.open` | `{sessionId}` | — |

**ActivityKit**: attributes `sessionId: String`, `startedAt: Date`. ContentState `players`, `round`, `phase`, `takerLabel?`, `giverLabel?`, `takerSeat?`, `giverSeat?`, `mode?`, `ended`.

**URL**: `spinfolk://session/<id>`, id = 32 lowercase hex.

**Payload** (`activityPayload`, pure):

| Phase | Roles in payload |
|---|---|
| `revealed` | current taker, giver, both labels; no mode |
| `challenge` | current taker, giver, both labels, mode |
| `ready` | last logged round's taker, giver, labels, mode if it ended with Truth or Dare and both seats still exist; otherwise none |

**Sync rules** (`LiveActivitySync`)

| Bloc state | Action |
|---|---|
| spinning | nothing |
| carries a session, payload ≠ last sent | if the session id changed: `activity.end` for the old one first; then `activity.sync`; report status |
| carries a session, payload = last sent | nothing |
| no session, and one was known | `activity.end {sessionId, rounds: log.length}` |
| launch, and every return to foreground | `activity.reconcile {current id or null}`, then forced sync if a session exists and it is not spinning |

## 7. Acceptance checks

Static (run in this phase, real output pasted)
- P4-1 `ruby tool/add_widget_target.rb` prints the phase order ending `Embed Frameworks > Embed Foundation Extensions > Thin Binary`; a second run prints "already present".
- P4-2 `fvm dart run build_runner build --delete-conflicting-outputs`; `fvm dart format --set-exit-if-changed .`; `fvm flutter analyze` clean; `tool/check_rules.sh` OK; `fvm flutter test` passes.
- P4-3 `fvm flutter build ios --simulator --debug` succeeds with no "Cycle inside Runner".
- P4-4 Bundle inspection (commands in guidelines §4): `.appex` embedded; versions and minimum OS equal to the app's; bundle ids as decided; `NSSupportsLiveActivities` true; scheme `spinfolk` registered; extension point `com.apple.widgetkit-extension`.
- P4-5 `grep -c DEVELOPMENT_TEAM ios/Runner.xcodeproj/project.pbxproj` → 0; no `.entitlements`, no Podfile, no `UIBackgroundModes`; `git diff phase-3 -- pubspec.yaml pubspec.lock` empty.
- P4-6 `SpinfolkAttributes.swift` is compiled by both targets and by nothing else twice (`grep -c` → 6 lines in the project file).

Behaviour proven by tests
- P4-7 `activityPayload`: exact maps for ready (first round), revealed, challenge (both modes), ready with a last Truth/Dare round, ready after a passed round, named players.
- P4-8 `LiveActivitySync` over a full loop: one `activity.sync` per trigger of §6, none while spinning, none for replay or failures; backgrounded reveal syncs; players edited syncs; end sends `activity.end` with the right id and round; a changed session id ends the old one first; calls arrive in order.
- P4-9 Launch: stored session → `activity.reconcile {id}` then `activity.sync`; nothing stored → `activity.reconcile {null}` only. `onResume` repeats it.
- P4-10 Status: `disabled` reaches `SettingsCubit` and the sheet shows the line; `active` and `error` show none; a throwing or missing channel never throws into the bloc or the UI.
- P4-11 Links: `url.ready` is sent after the handler is set; `url.open` with the stored id resumes a not-yet-resumed session and lands on the game route; a foreign id, a malformed id and a non-map argument are ignored; a link during an active game changes nothing.

Deferred to the post-Phase-5 device pass (flows written now, **NOT VERIFIED** in this phase)
- P4-D1 Activity starts on session start (one-line card).
- P4-D2 Updates after reveal, mode chosen, next round; never during the spin.
- P4-D3 Lock Screen, compact, minimal and expanded layouts match the canvas.
- P4-D4 Tap returns to the session, warm and cold.
- P4-D5 End Session ends the activity at once.
- P4-D6 Relaunch reconciles: no duplicate, foreign activity removed.
- P4-D7 Live Activities off in iOS Settings: play is unaffected, the sheet shows the line.
- P4-D8 Real device (needs the team id): the same on hardware.

## 8. Risks

| Risk | Likelihood | Handling |
|---|---|---|
| Runtime behaviour of ActivityKit code is unverified until the device pass (compile-only gate). | Certain | The Swift is isolated in two files; Dart logic is fully unit-tested against the channel contract; P4-D1…D7 flows are ready. |
| Phase 2b / Phase 3 changed `project.pbxproj` or `NativeChannel` in a way the script or the Swift does not expect. | Medium | The script finds everything by name and aborts with a message instead of guessing; `git checkout` restores the project file. Reconcile checklist first. |
| Phase 2b exposes no "last round" in bloc state. | Medium | Stop and report; do not add a repository call to `LiveActivitySync`. Fallback approved here: ship without "Last round" content (D11 "otherwise none"). |
| Cold-start link arrives before the scene's Flutter engine exists. | Low | `NativeChannel` is a process-wide singleton that holds the id until `url.ready`; it does not need the channel to exist yet. |
| `flutter build ios` (device) fails for lack of a team. | Certain | Out of scope until Phase 5; only the simulator build is a gate. |
| Extension grows a dependency on Flutter or a plugin by accident. | Low | The extension target has no package product dependencies; `APPLICATION_EXTENSION_API_ONLY = YES`. |
| Names appear on the Lock Screen. | By design | Spec A8 sends labels. Listed as open question 2. |

## 9. Open questions

None block the simulator-level work.

1. **Team ID** is still unconfirmed. Needed before any device build, P4-D8 and TestFlight. It must be supplied outside the repo or added by the owner; this phase adds none.
2. **Names on the Lock Screen.** Labels such as "Riya · P1" are visible on a locked phone, as the spec's `takerLabel` / `giverLabel` imply. Default: shown. Alternative: seat numbers only on the Lock Screen.
3. **Passed last round.** After a pass the activity shows no roles (D11) rather than "Last round: Pass" with the passed pair. Say so if the pair should be shown.
4. **Re-validation.** Like Phase 3, this plan predates the Phase 2b code. A short read of guidelines §0 against the real code is advised before implementation.

## Owner decisions (2026-11-22) — do not reopen
- All open-question defaults in this PRD approved as written.
- Glass: adaptive_platform_ui IOS26Button for the 5 chrome buttons (accept its medium haptic); cards/toast/confirm cards solid.
- History swipe: full-swipe Dismissible delete + undo toast (no resting Delete button).
- Zero-round games are not saved to History.
- Voices follow device language; mode line spoken only on Replay; player names shown on Lock Screen; after a pass the Live Activity shows no roles.
- Evidence screenshots stay out of git; simulator/Maestro automation runs once after all phases.
