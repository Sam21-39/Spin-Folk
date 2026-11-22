# Spinfolk — Technical Flow + Build Prompt (v2: BLoC · get_it/injectable · go_router · SQLite)

Owner: Sumit Pal (GitHub `Sam21-39`) · Repo: `Sam21-39/Spin-Folk` · Display name **Spinfolk** · Dart package `spinfolk`
Design source of truth: Spinfolk Design System canvas (Foundations, Components, Dial & bottle, Screens, Logo, Live Activity) — approved 22 Nov 2026. Local copy of every artboard: `docs/design/project/*.dc.html`.

v2 replaces GetX/GetStorage (from `CLAUDE_HANDOFF.md`) with **BLoC + Cubit**, **get_it + injectable**, **go_router**, a **lean Clean Architecture**, **SQLite (sqflite)** for the session and **shared_preferences** for preferences. There is **no `setState` and no context-driven logic in the UI**. Where this file and `CLAUDE_HANDOFF.md` disagree, this file wins.

---

## Part A — Technical flow

### A1. Corrections to the original brief (and why)

| # | Original brief | Correction | Reason |
|---|---|---|---|
| 1 | GetX for state, routing and DI; GetStorage | **flutter_bloc** (Bloc for the session, Cubits for setup and settings), **get_it + injectable** for DI, **go_router** for routing, **sqflite** for the session, **shared_preferences** for preferences. | Owner's decision. |
| 2 | "Flutter 3.50, standard packages" | Pin Flutter **3.50.x / Dart 3.14** with FVM. App code uses the current recommended Material import, and deprecation infos coming from dependencies are acceptable. | Flutter 3.50 deprecates the built-in `material.dart` and `cupertino.dart` in favor of standalone packages. |
| 3 | Full Clean Architecture implied | **Lean** Clean Architecture: domain (entities, pure rules, repository contracts), data (sqflite/prefs sources plus repository implementations), presentation (blocs and cubits plus widgets). **No use-case classes.** | Each use case would be a one-line pass-through. |
| 4 | go_router | Use it, keeping routes few and **state-driven** (`redirect` + `refreshListenable` on SessionBloc). | go_router is in maintenance mode; stable enough for 7 routes. |
| 5 | SQLite for "storage" | sqflite with **two tables**. Invariants enforced by **SQL CHECK constraints plus a singleton row**, transactions on every multi-row write, and `PRAGMA user_version` migrations. | DB refuses impossible state. |
| 6 | "Persist current phase incl. spinning" | Storage **never holds `spinning`**. Outcome written as `revealed` before animation starts; `spinning` lives only in bloc state. | Killed app never resumes half-spin; outcome never re-rolled. |
| 7 | "Use packages for Live Activities" | **Own ~120-line ActivityKit bridge** over a MethodChannel. No package, no App Group. | Less dependency surface. |
| 8 | "Tap returns to session" | `FlutterDeepLinkingEnabled = NO`. SceneDelegate forwards `spinfolk://session/<id>` over the channel; bloc validates it. | Keeps raw URLs out of go_router. |
| 9 | Min iOS unspecified | **iOS 17.0**. Glass on iOS 26+, `.ultraThinMaterial` on 17–25. | One code path for ActivityKit and SwiftUI wheel. |
| 10 | Speech settings vague | `.playback` + `.mixWithOthers` + `.duckOthers`. **No background modes, no microphone permission.** | `.ambient` silenced by mute switch. |
| 11 | "Update Live Activity on round changes" | Push updates **after reveal animation completes**, on mode chosen, and on Next/Pass/End. Never at spin start. | Avoid spoiling result on Lock Screen. |
| 12 | "Native glass over the scene" | **Two native islands only**: `NativePicker` and `NativeActionBar`, SwiftUI in `UiKitView`, placed below the dial. | Less composition cost. Phase 1 proves glass samples Flutter content behind it. |
| 13 | Canvas font "SF Pro Rounded" | Flutter bundles **Nunito ExtraBold** (OFL) for seat numerals. Native views and widget use `.fontDesign(.rounded)`. | Apple licence forbids bundling SF fonts. |
| 14 | Players 1–60 | Players **2–60**. | Giver and taker must be distinct. |
| 15 | "Beta + TestFlight in 1–2 h" | Playable core in **4–6 h**. Full scope **1–2 days**. | Honest estimate. |

### A2. Layers + dependency rule

- Presentation: Pages (StatelessWidget, BlocBuilder/BlocSelector); SessionBloc, SetupCubit, SettingsCubit; SpinStage (owns AnimationController, no setState) + DialPainter.
- Domain (pure Dart, no Flutter imports): Entities Session, Player, Outcome, Phase, Mode, Prefs; Rules pickRoles, isValidPair, spinPlan, speechLine, displayLabel; Contracts SessionRepository, PrefsRepository.
- Data: SessionRepositoryImpl → SessionDb (sqflite); PrefsRepositoryImpl → SharedPreferencesWithCache.
- Platform services (injected singletons): NativeBridge (MethodChannel); LiveActivitySync (listens to SessionBloc.stream); Announcer (native AVSpeechSynthesizer via `spinfolk/native` channel, listens to SessionBloc.stream); AppNavigator (wraps GoRouter).

**Rules:**
- Domain imports nothing from Flutter, sqflite or get_it.
- Presentation never imports data.
- Blocs and cubits never receive a `BuildContext`, never navigate, never show dialogs.
- Side effects (Live Activity, speech) react to the bloc stream from injected services, not from widgets.

### A3. No-`setState`, no-context-logic conventions

| Need | How |
|---|---|
| Screen state | BlocBuilder / BlocSelector only. Every widget is a `StatelessWidget` except `SpinStage`. |
| Animation ticker | `SpinStage` is a `StatefulWidget` purely to own the `AnimationController`. **No `setState`.** `CustomPaint(painter: DialPainter(repaint: controller))`. Receives a `SpinPlan` from state and reports `SpinAnimationFinished`. |
| Dispatching events | Widget callbacks only forward intent (`context.read<SessionBloc>().add(SpinRequested())`). |
| Navigation | Session flow is **redirect-driven** from `SessionBloc.state`. User pushes (Add Names, Settings sheet, End confirm) go through injected `AppNavigator`. Sheets and dialogs are **routes** (`CustomTransitionPage`), never `showDialog`/`showModalBottomSheet`. |
| Errors / notices | Fields in state (`notice`, `failure`) rendered inline. No SnackBar/ScaffoldMessenger. |
| Enforcement | CI step: `! grep -rn "setState(" lib/` and `! grep -rn "BuildContext" lib/features/*/presentation/bloc lib/features/*/presentation/cubit lib/features/*/domain lib/features/*/data`. |

### A4. Round state machine (SessionBloc)

```
[*] → loading: AppStarted
loading → noSession: repo.load() = null or corrupt (notice)
loading → resumePrompt: valid session
resumePrompt → active: ResumeConfirmed
resumePrompt → noSession: EndConfirmed
noSession → active_ready: SessionStarted(count, names) → tx insert
active_ready → active_spinning: SpinRequested → emit spinning, persist revealed
active_spinning → active_revealed: SpinAnimationFinished
active_spinning → active_revealed: AppBackgrounded / process killed
active_revealed → active_challenge: ModeChosen(truth|dare)
active_revealed → active_ready: Passed (round++)
active_challenge → active_ready: NextRound / Passed (round++)
active_ready → active_ready: PlayersEdited (tx replace players, keep id)
active_ready|revealed|challenge → noSession: EndConfirmed
```

**Double-spin guard:** `SpinRequested` handler emits `spinning: true` before its first `await`, returns immediately if already spinning or phase isn't `ready`. Test must cover this. If persist fails, emit back `ready` with failure notice.

**State shape (sealed):** `SessionLoading | NoSession(notice?) | ResumePrompt(session) | SessionActive(session, spinning, spinPlan?, orientation, failure?)`. `orientation` lives only in memory; after restore it is θ(taker), or 0.

### A5. Selection + rotation math (`domain/rules/selection.dart`, pure)

```
seat angle   θ(i) = 2π·i / N          (0 = twelve o'clock, clockwise)
taker        t ~ Uniform[0, N)
giver        even N : (t + N/2) mod N
             odd  N : coin flip between (t + ⌊N/2⌋) mod N and (t + ⌈N/2⌉) mod N
             N = 2  : 1 − t
bottle art   drawn neck-up ⇒ orientation φ points neck at φ (no offset)
spinPlan     δ = ((θ(t) − r mod 2π) mod 2π + 2π) mod 2π
             turns ∈ {5, 6};  end = r + turns·2π + δ
             durationMs = 4400 + (turns − 5)·600 + (δ/2π)·400
             after reveal r = end mod 2π
curve        Cubic(0.15, 0.60, 0.10, 1.00); Reduce Motion → 600 ms crossfade, same outcome
```

`Random` injected via injectable (`@module` providing `Random()`). Tests use `Random(seed)`. No anti-repeat logic.

### A6. SQLite schema (`spinfolk.db`, sqflite)

```sql
PRAGMA foreign_keys = ON;          -- run in onConfigure
-- version via openDatabase(version: 1, onCreate, onUpgrade)

CREATE TABLE session (
  id          TEXT    PRIMARY KEY,                      -- 32 hex, Random.secure
  singleton   INTEGER NOT NULL DEFAULT 1 UNIQUE CHECK (singleton = 1),
  started_at  INTEGER NOT NULL,                         -- epoch ms UTC
  player_count INTEGER NOT NULL CHECK (player_count BETWEEN 2 AND 60),
  round       INTEGER NOT NULL CHECK (round >= 1),
  phase       TEXT    NOT NULL CHECK (phase IN ('ready','revealed','challenge')),
  taker       INTEGER,
  giver       INTEGER,
  mode        TEXT    CHECK (mode IN ('truth','dare')),
  CHECK (
    (phase = 'ready'     AND taker IS NULL AND giver IS NULL AND mode IS NULL) OR
    (phase = 'revealed'  AND taker IS NOT NULL AND giver IS NOT NULL AND mode IS NULL) OR
    (phase = 'challenge' AND taker IS NOT NULL AND giver IS NOT NULL AND mode IS NOT NULL)
  ),
  CHECK (taker IS NULL OR (taker BETWEEN 0 AND player_count - 1)),
  CHECK (giver IS NULL OR (giver BETWEEN 0 AND player_count - 1)),
  CHECK (taker IS NULL OR taker <> giver)
);

CREATE TABLE player (
  session_id TEXT    NOT NULL REFERENCES session(id) ON DELETE CASCADE,
  seat       INTEGER NOT NULL CHECK (seat BETWEEN 0 AND 59),
  name       TEXT    CHECK (name IS NULL OR length(name) BETWEEN 1 AND 40),
  PRIMARY KEY (session_id, seat)
);
```

Repository behavior:
- `load()` reads both tables, validates in domain (seats contiguous `0..count-1`, `isValidPair`). Returns `Session?` or `CorruptSession`. On corrupt: delete rows; bloc emits `NoSession(notice: "Couldn't restore the last game")`.
- `start()` and `replacePlayers()` in `db.transaction`.
- Round updates: single `UPDATE`.
- `end()`: `DELETE FROM session`; cascade removes players.
- Every write awaited before bloc treats state as saved. `DatabaseException` → `StorageFailure`, shown inline; in-memory state kept for retry.

Preferences (`SharedPreferencesWithCache`, allowList) never touched by End Session:

| Key | Type | Default |
|---|---|---|
| `announce` | bool | `true` |
| `voiceId` | String? | `null` |
| `rate` | double | `0.5` |

### A7. Native contracts

Shared channel `spinfolk/native`:

| Direction | Method | Args | Result |
|---|---|---|---|
| Dart → iOS | `activity.sync` | `{sessionId, startedAt, players, round, phase, taker?, giver?, mode?, takerLabel?, giverLabel?}` | `{state: "active"/"disabled"/"unsupported"/"error", message?}`. Starts activity if none for session, else updates. Ends duplicates and other sessions' activities. |
| Dart → iOS | `activity.end` | `{sessionId, rounds}` | `{ok: bool}` (final content + `.immediate` dismissal) |
| Dart → iOS | `activity.reconcile` | `{sessionId?}` | `{ended: int}`. Ends every activity whose id differs from current session, or all when null. |
| iOS → Dart | `url.open` | `{sessionId}` | — SessionBloc validates against stored id, ignores mismatches |

Per-view channels (`spinfolk/picker/<viewId>`, `spinfolk/actionbar/<viewId>`):

| View | Dart → iOS | iOS → Dart |
|---|---|---|
| Picker | `config {min:2,max:60,value}` | `changed {value}` → `SetupCubit.countChanged` |
| ActionBar | `config {items:[{id,label,style:"primary"/"secondary"/"destructive"/"choice",enabled}], layout:"stack"/"row"}` | `tap {id}` → mapped to bloc event by the page |

Native views fill the rect Flutter gives them; Flutter owns layout and safe areas. VoiceOver labels; Dynamic Type up to `.accessibility2`.

### A8. Live Activity data

- Attributes (static): `sessionId`, `startedAt`.
- ContentState: `players`, `round`, `phase`, `takerLabel?`, `giverLabel?`, `takerSeat?`, `giverSeat?`, `mode?`, `ended`.
- Layouts per canvas (`docs/design/project/LiveActivity.dc.html`): Lock Screen two role tiles; compact mark + `giver › taker`; minimal mark; expanded giver → taker, round, players.
- Lifetime ≤ 8 h. `staleDate` = start + 8 h. On foreground: `reconcile`, then `sync` re-requests if allowed. No background restart.
- `LiveActivitySync` subscribes to `SessionBloc.stream`; calls `sync` only on: session started, `spinning → revealed`, mode chosen, round advanced, players edited. Calls `end` on `→ NoSession`.
- Disabled/unsupported reported to `SettingsCubit` as one quiet line. Gameplay never blocked.

### A9. Folder structure

```
lib/
  main.dart                         # WidgetsFlutterBinding; await configureDependencies(); getIt<LiveActivitySync>().start(); getIt<Announcer>().start(); runApp(const SpinfolkApp())
  app/
    app.dart                        # MultiBlocProvider(getIt blocs) + MaterialApp.router(routerConfig: getIt<GoRouter>())
    router.dart                     # @module provides GoRouter: routes, redirect(SessionBloc.state), refreshListenable
    app_navigator.dart              # @lazySingleton: pushNames(), openSettings(), confirmEnd(), pop()
    bloc_listenable.dart            # ~10 lines: Stream → ChangeNotifier
    tokens.dart                     # colors, radii, spacing, durations from canvas
  core/
    di/injection.dart (+ injection.config.dart generated)   # @InjectableInit, @module: Random, SharedPreferencesWithCache (@preResolve), Database (@preResolve)
    failure.dart                    # sealed Failure: StorageFailure, CorruptSession
  features/
    session/
      domain/entities/session.dart
      domain/rules/selection.dart
      domain/rules/labels.dart
      domain/session_repository.dart
      data/session_db.dart
      data/session_repository_impl.dart
      presentation/bloc/session_bloc.dart (+ _event.dart, _state.dart)
      presentation/pages/resume_page.dart
    setup/
      presentation/cubit/setup_cubit.dart
      presentation/pages/new_game_page.dart, add_names_page.dart
    game/
      presentation/pages/game_page.dart
      presentation/widgets/spin_stage.dart
      presentation/widgets/dial_painter.dart, role_cards.dart
      presentation/pages/end_confirm_page.dart
    settings/
      domain/prefs.dart, domain/prefs_repository.dart
      data/prefs_repository_impl.dart
      presentation/cubit/settings_cubit.dart
      presentation/pages/settings_sheet_page.dart
  platform/
    native_bridge.dart
    live_activity_sync.dart
    announcer.dart
    native_picker.dart, native_action_bar.dart
ios/Runner/Native/  PickerView.swift  ActionBarView.swift  LiveActivityBridge.swift  SpinfolkAttributes.swift (Runner + widget targets)
ios/SpinfolkWidget/ SpinfolkLiveActivity.swift  Info.plist
test/
  selection_test.dart  session_bloc_test.dart  session_repository_test.dart (sqflite_common_ffi in-memory)  labels_test.dart
```

Dependencies (pin exact; commit `pubspec.lock`; re-check versions):
- Runtime: `flutter_bloc` (9.x), `get_it` (9.x), `injectable` (3.x), `go_router` (latest stable), `sqflite`, `shared_preferences` (2.3+). NO flutter_tts (owner decision 2026-11-22: no SPM support; speech is native AVSpeechSynthesizer behind `spinfolk/native` — methods `speech.speak {text, voiceId?, rate}`, `speech.stop`, `speech.voices {language}` → `[{id,name,language,quality}]`; iOS→Dart `speech.event {state: done|cancelled|error}`).
- Dev: `injectable_generator`, `build_runner`, `sqflite_common_ffi`, `flutter_lints`.
- Deliberately not added: `equatable`, `bloc_concurrency`, `bloc_test`, `mocktail`, `freezed`, `path`, any live-activities or glass package.

---

## Part B — Build prompt

ROLE: Senior Flutter + iOS engineer building "Spinfolk", offline single-phone Truth-or-Dare spin-the-bottle party app, iPhone-first. Phased; every phase runnable; report honestly. Never invent test results, device verification, Apple team IDs, bundle IDs, signing assets or App Store Connect records. Never ask for passwords or tokens in chat.

OWNER / IDENTIFIERS
- Repo Sam21-39/Spin-Folk exists (verified); `origin` already set.
- Display name Spinfolk; Dart package spinfolk.
- Bundle ID (owner decision 2026-11-22): `in.appamania.spinfolk`, widget `in.appamania.spinfolk.SpinfolkWidget`. Org for `flutter create`: `in.appamania`. Team ID not confirmed yet.

SCOPE: Numbered players 2–60 (optional names), native wheel picker, Start/Resume/End session, Flutter-drawn dial + bottle, neck = TAKER (teal #2DD4BF), base = GIVER (coral #FF7A59), Truth / Dare / Pass, Next Round, spoken announcement + Replay, voice settings, persisted session, Live Activity + Dynamic Island.
OUT OF SCOPE: backend, accounts, sync, ads, analytics, multiplayer, scores, challenge generator/library, solo mode, light theme, Android polish.

ARCHITECTURE (fixed — do not re-litigate)
- Flutter 3.50.x stable (Dart 3.14) pinned with FVM (.fvmrc). Don't upgrade global tooling. App code uses current recommended Material import for 3.50; dependency deprecation infos acceptable—note, don't patch.
- Lean Clean Architecture, feature-first. Domain: NO Flutter/sqflite/get_it imports. NO use-case classes.
- State: flutter_bloc. SessionBloc, SetupCubit (count 2–60 + names), SettingsCubit (prefs, voices, LA status). Sealed immutable state classes, hand-written ==/hashCode.
- DI: get_it + injectable (@injectable/@lazySingleton/@singleton, @module for Random, Database, SharedPreferencesWithCache with @preResolve). Generated file committed. `dart run build_runner build --delete-conflicting-outputs`.
- Routing: go_router from an @module. Routes: /new, /names, /resume, /game, /game/settings (sheet page), /game/end (dialog page). Redirect-driven from SessionBloc.state with refreshListenable. User pushes via injected AppNavigator. Sheets/dialogs are routes (CustomTransitionPage).
- NO setState in lib/. NO BuildContext in domain, data, blocs or cubits. Widgets StatelessWidget except SpinStage (StatefulWidget ONLY to own AnimationController; CustomPaint(painter: DialPainter(repaint: controller)); reacts to state.spinPlan via BlocListener; adds SpinAnimationFinished on completion). Widget callbacks only forward intent. No SnackBar/ScaffoldMessenger. Script check (tool/check_rules.sh) greps for `setState(` in lib/ and `BuildContext` in domain/data/bloc/cubit folders; fails if found.
- LiveActivitySync and Announcer: injected singletons subscribed to SessionBloc.stream (started in main after DI).
- Storage: sqflite. Preferences: SharedPreferencesWithCache (allowList {announce, voiceId, rate}).
- iOS minimum 17.0. Liquid Glass via SwiftUI `.glassEffect` / `.buttonStyle(.glass/.glassProminent)` under `if #available(iOS 26, *)`, else `.ultraThinMaterial`, identical shapes. Never fake glass with BackdropFilter/shaders.
- Exactly TWO native platform-view islands (SwiftUI in UIHostingController inside FlutterPlatformView via UiKitView): NativePicker (wheel 2–60 in glass card) and NativeActionBar (glass capsules incl. Truth/Dare pair). Action bar BELOW dial, never overlapping. No per-seat native views.
- Own ActivityKit bridge on MethodChannel 'spinfolk/native'; no live-activities package, no App Group.
- Info.plist: FlutterDeepLinkingEnabled = NO; URL scheme `spinfolk`; NSSupportsLiveActivities = YES. No NSMicrophoneUsageDescription, no UIBackgroundModes.
- Speech audio session: .playback + .mixWithOthers + .duckOthers (AVAudioSession in Swift, activated only while speaking, deactivated with .notifyOthersOnDeactivation). Stop speech on background.
- Dependencies exactly as A9. Nothing else without asking.

DESIGN TOKENS (approved canvas; see `docs/design/project/Main.dc.html`, `Components.dc.html`, `Dial.dc.html`)
Colors: bg.base #0B1424, bg.surface #121E33, bg.raised #1A2A45, line #2A3B5E, taker #2DD4BF, giver #FF7A59, text.primary #F2F5FA, text.secondary #A9B6CC, text.tertiary #8191AB. Dark only.
Type: system font for UI text. Bundle Nunito ExtraBold (OFL; register licence in LicenseRegistry) for seat numerals + player callouts with tabular figures. Native islands + widget use `.fontDesign(.rounded)`. Scale: role display 44/48, large title 34 bold, title2 22 bold, headline 17 semibold, body 17, footnote 13. Respect text scaling; clamp only dial labels.
Spacing 4-pt (4,8,12,16,24,32,48), margin 20. Radii 12/20/28/capsule. Touch ≥ 44 pt; Spin 64 pt.
Motion: spin per spinPlan, curve Cubic(0.15,0.60,0.10,1.00); reveal pulse 2×600 ms scale 1.0→1.18 on selected seats; panel enter 320 ms. Reduce Motion (MediaQuery.disableAnimations, read in widget build only): 600 ms crossfade, same outcome. Haptic: HapticFeedback.mediumImpact once at stop. No confetti, no flashing.
Dial: seat 0 at 12 o'clock, clockwise. N ≤ 12 numbered discs (r 15, selected r 18 + 7 px halo); N > 12 ticks (every 5th labelled; selected long colored tick + number). Bottle: neutral frosted body, teal lip (neck/taker), coral base band (giver), drawn neck-up, length 62% of dial radius. Odd N: dotted coral arc on inner radius from base direction to giver seat; bottle stays straight. Dial = one Semantics node ("Taker Player 7, Giver Player 3").
Roles ALWAYS in text ("TAKER"/"GIVER") + icon (neck arrow / base bar). Named players "Riya · P1" (seat number always kept; one line ellipsis; full text in semantics).
Screens (artboards in `docs/design/project/`): New Game, Add Names, Resume, Game·Ready, Game·Spinning ("Spinning…" disabled + "Result is already locked in. Leaving the app won't change it."), Game·Revealed (role cards, announcement line + Replay, Truth/Dare equal weight, separate Pass, "Anyone can pass. No penalty."), Game·Challenge ("Player 3 asks Player 7 a question, out loud." + "The app doesn't write challenges. The group does."), 60-player + long-name state, Session sheet (Announcements, Voice, Speed, Preview, Edit Players, End Session, LA status line), End confirmation ("Clears N players and R rounds. Voice settings stay. Lock Screen activity ends too."). Logo/app icon per canvas `Logo.dc.html` (8-dot ring, bottle at 45°, teal lip, coral base); generate 1024 px icon from same geometry with a small script.

DOMAIN RULES (pure)
- θ(i) = 2πi/N from 12 o'clock, clockwise. 0-based internally; display i+1.
- pickRoles(n, Random rng): taker = rng.nextInt(n); even n → giver = (taker + n~/2) % n; odd n → rng.nextBool() ? (taker + n~/2) % n : (taker + (n+1)~/2) % n. Assert 2 ≤ n ≤ 60.
- isValidPair(n, taker, giver).
- spinPlan(current, taker, n, rng) → (end, turns, durationMs) per A5.
- labels.dart: displayLabel(player); speechLine(session): "<giver>, give a challenge to <taker>." using name only if unique among players, else "Player N"; mode line "<taker> chose Truth."

SESSION BLOC
Events: AppStarted, ResumeConfirmed, SessionStarted(count, names), SpinRequested, SpinAnimationFinished, ModeChosen(mode), Passed, NextRoundRequested, PlayersEdited(count, names), EndConfirmed, AppBackgrounded, SessionLinkOpened(id), ReplayRequested.
- SpinRequested: ignore if spinning or phase != ready. Emit spinning:true + spinPlan BEFORE first await. Then await repo.saveOutcome. On StorageFailure → emit ready, spinning:false, failure. Never re-roll an existing outcome.
- SpinAnimationFinished: spinning:false, orientation = end % 2π.
- AppBackgrounded while spinning: same as finished. Announcer must NOT speak for this path or restores — only on live spinning→revealed from SpinAnimationFinished.
- Passed / NextRoundRequested: round+1, phase ready, clear roles/mode (single UPDATE).
- PlayersEdited: only phase ready && !spinning; transaction replaces players, keeps id.
- EndConfirmed: await repo.end(); on failure keep session + failure.
- SessionLinkOpened(id): ignore unless id == current id.
Constructor takes SessionRepository and Random.

SPEECH: speaks speechLine after live reveal when announce on; Replay via ReplayRequested. Voice list = getVoices filtered to device language. Error/unavailable/interrupted → notice "Voice unavailable. Read the roles aloud." No retry loops.

NATIVE (ios/)
- PickerView.swift: factory "spinfolk/picker"; SwiftUI Picker(.wheel) in glass card; channel config ↓, changed ↑.
- ActionBarView.swift: factory "spinfolk/actionbar"; glass capsules (primary .glassProminent on 26+, destructive coral label, choice equal-weight pair); tap {id} ↑; config updates without recreating view. Dynamic Type; VoiceOver.
- Manage UIHostingController lifetime; release on dispose; no retain cycles.
- LiveActivityBridge.swift per A7.
- SceneDelegate: spinfolk://session/<id> cold + warm → 'url.open {sessionId}' (queue until Dart registers handler).
- SpinfolkWidget extension per A8.

PHASES + GATES (after each: what works, checks run with real output, blockers, next step)
- Phase 0 — Baseline: inspect tooling; pin Flutter 3.50.x via FVM; create app (--platforms ios --project-name spinfolk); add pinned deps; DI skeleton + codegen runs; empty router. Gate: builds and launches on iOS 26 simulator; analyzer clean.
- Phase 1 — Native glass proof: picker + glass action bar over dark Flutter background with colorful test painter. Gate: picker value reaches SetupCubit; cubit state toggles native enabled; glass samples Flutter content (screenshot); no blocked touches; no jank in 10 s test spin; Reduce Transparency/Motion checked. If sampling fails, propose real native layout fix — never fake.
- Phase 2 — Domain + data + setup/game UI. Gate: complete loop on simulator for N = 2, 3, 5, 7, 59, 60; SE-size + largest text without overflow; grep check passes.
- Phase 3 — Persistence, prefs, speech, lifecycle. Gate: prefs persist; resume after background and kill (kill mid-spin → completed reveal, no reroll, no auto-speech); End clears DB, keeps prefs; corrupt row → notice + clean Setup; speech interruption handled.
- Phase 4 — Live Activity + Dynamic Island. Gate on simulator: start on session start, update after reveal/mode/next, layouts render, tap returns to session, End ends it, relaunch reconciles, disabled auth doesn't block play.
- Phase 5 — Proof + TestFlight. `fvm dart format --set-exit-if-changed .`, `fvm flutter analyze`, `fvm flutter test`, grep check. Tests: selection_test, rotation, session_bloc_test (fake repo + Random(seed)), session_repository_test (sqflite_common_ffi), labels_test. Audit Info.plist, deps, release config, bundle IDs, version 0.1.0+1, icon, no secrets (.gitignore: *.mobileprovision, *.p12, *.cer, *.p8). TestFlight only with confirmed signing + final bundle ID.

README (short): FVM setup, pinned versions, codegen command, run/test commands, architecture map, iOS/signing prerequisites, gameplay, odd-player rule, known limits.

STYLE: Small diffs. No speculative abstractions. One authoritative source per fact. Comment only non-obvious decisions. Don't stub a requested feature silently.

---

## Amendments — Phase 2b (2026-11-22)

Owner added the "Flow v2 · History" design page and asked for `adaptive_platform_ui`. These override A1-12, A4, A6 `end()`, the A9 "deliberately not added: any glass package" line and the Part B route list. Details live in `docs/plans/phase-2b/prd.md` (single source):

- **Glass rule** (prd §6.1): own `NativePicker` + `NativeActionBar` for the wheel and all bars; `adaptive_platform_ui` 1.0.2 `IOS26Button`, imported only via `lib/platform/glass_button.dart`, for chrome buttons. Package blur view, alert dialog, snackbar, scaffold and menus are banned. Cards stay solid. Never fake glass.
- **Dependency:** `adaptive_platform_ui: 1.0.2` (SwiftPM).
- **State/events** (prd §6.2): adds `SessionSummary(game)` state and `SummaryDismissed` event.
- **Routes** (prd §6.3): `/` Home hub (replaces `/resume`), `/history`, `/history/clear`, `/history/:id`, `/history/:id/delete`, `/game/log`, `/summary`, plus existing setup/game routes.
- **Schema v2** (prd §6.4): additive tables `round_log`, `game`, `game_player`, `game_round`; v1 tables unchanged.
- End Session archives to History; a game with no logged round is not saved.
