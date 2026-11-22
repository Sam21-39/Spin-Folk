# Spinfolk — Phase 2 (domain + data + setup/game UI): Technical PRD

Date: 2026-11-22 · Spec: `docs/spec-v2.md` (authoritative; architecture fixed) · Builds on: `docs/plans/phase-0-1/` · Companion: `guidelines.md` in this folder.

## 1. Problem

After Phase 0–1 the app is a pinned Flutter shell with two proven native glass islands, a count-only `SetupCubit`, and a throwaway proof harness. There is no game. Phase 2 delivers the whole playable loop on one phone:

New Game → (optional names) → Start → Spin → Reveal → Truth / Dare / Pass → Next Round → … → End Session, with the session stored in SQLite so a relaunch offers Resume.

Speech, preferences, lifecycle handling and the Live Activity are later phases. Phase 2 must leave clean seams for them without stubbing them.

## 2. Verified facts (checked 2026-11-22, not assumed)

| Fact | Source |
|---|---|
| Phase 1 code exists on branch `phase-0-1`: `lib/platform/native_{island,picker,action_bar}.dart`, `SetupCubit` (count only, `@injectable`, provided app-wide), `RouterModule` with one TEMP `/new` route, synchronous `configureDependencies()`, `tool/check_rules.sh`. Evidence PNGs p0/p1 are present. | repo read |
| `flutter_tts` is removed and there is no `ios/Podfile`; iOS plugins resolve through SwiftPM. Speech will be native `AVSpeechSynthesizer` behind `spinfolk/native` (Phase 3). | `pubspec.yaml`, `ios/`, spec line 224 |
| Pinned: `material_ui 1.1.0`, `flutter_bloc 9.1.1`, `get_it 9.3.0`, `injectable 3.0.0`, `go_router 18.1.4`, `sqflite 2.4.6`, `sqflite_common_ffi 2.4.7` (dev). | `pubspec.yaml` |
| Native action bar: `primary` min height 64, others 50; stack spacing 10, row spacing 12; content bottom-aligned in the rect Flutter gives; Dynamic Type clamped at `.accessibility2`. | `ios/Runner/Native/ActionBarView.swift` |
| go_router 18.1.4: on `refreshListenable`, the current match list is re-parsed as `restore`; the top-level `redirect` runs against the current URI; if it returns a different location the whole stack is replaced, otherwise the stack is kept. Imperative `push` entries are not individually re-checked. | `go_router-18.1.4/lib/src/parser.dart` (`_updateRouteMatchList`), `configuration.dart` (`applyTopLegacyRedirect`) |
| `CustomTransitionPage` supports `opaque: false`, `barrierDismissible`, `barrierColor`. | `go_router-18.1.4/lib/src/pages/custom_transition_page.dart` |
| sqflite joins a relative database path with `getDatabasesPath()`, so `openDatabase('spinfolk.db')` needs no `path` package. | `sqflite_common-2.5.17/lib/src/factory_mixin.dart:243` |
| Upstream Nunito ships **only a variable font**. `https://raw.githubusercontent.com/google/fonts/main/ofl/nunito/Nunito%5Bwght%5D.ttf` → HTTP 200, 276 932 bytes; `…/ofl/nunito/OFL.txt` → 200. No static `Nunito-ExtraBold.ttf` exists in `googlefonts/nunito`. | `curl`, GitHub tree API |
| `iPhone SE (3rd generation)` device type is supported by the installed iOS 26.5 runtime (no SE simulator instance exists yet). `xcrun simctl ui <dev> content_size` accepts `extra-extra-extra-large` and `accessibility-extra-extra-extra-large`. | `xcrun simctl list runtimes -j`, `xcrun simctl ui` |
| Dial geometry (all artboards agree): outer disc radius `R = side/2 − 4`; seat ring `R − 24`; inner dashed ring `R − 50`; bottle scale `0.62·R / 96` on a path spanning y −98…84; odd-N arc radius `78 × scale`. Tick mode: outer end `R − 4`, lengths 8 / 13 (every 5th) / 22 (selected), labels at `R − 42`. | `docs/design/project/Dial.dc.html`, `Ready`, `Revealed`, `Crowd60` |
| Artboards show glass on elements that are **not** one of the two allowed islands: round pill, settings button, Replay, sheet "Done", End-confirm card. | `Ready`, `Revealed`, `Settings`, `EndConfirm` artboards |
| Schema A6 has no "previous round" columns, so the Resume artboard line "Last round: Player 2 gave Player 7 a Truth." cannot be derived once the phase is `ready`. | spec A6, `Resume.dc.html` |
| The Challenge artboard only shows Truth copy. No approved sentence exists for Dare. | `Challenge.dc.html`, `Components.dc.html` |

## 3. Scope

### In
- **Domain** (pure Dart): `Session`, `Player`, `Outcome`, `Phase`, `Mode`; `selection.dart` (`seatAngle`, `oppositeSeats`, `pickRoles`, `isValidPair`, `spinPlan`); `labels.dart` (`normalizeName`, `displayLabel`, `spokenName`, `speechLine`); `SessionRepository` contract; `Failure` types.
- **Data**: `session_db.dart` (schema A6 verbatim, open/configure), `SessionRepositoryImpl` on sqflite, `Database` provided by an `@preResolve` module.
- **SessionBloc** with the full event set of the spec, persistence-backed, strictly sequential event handling.
- **SetupCubit** extended with names (draft/commit), seeding for Edit Players, reset.
- **Routing**: `/new`, `/names`, `/resume`, `/game`, `/game/settings`, `/game/end`; pure `sessionRedirect`; `BlocListenable`; `AppNavigator`.
- **Screens**: New Game, Add Names, Resume, Game (ready / spinning / revealed / challenge, incl. 60-player and long-name states), Session sheet (Phase 2 form, see D10), End confirmation.
- **SpinStage + DialPainter**: disc mode N ≤ 12, tick mode N > 12, odd-N coral arc, bottle at 62 % radius, reveal pulse, Reduce Motion crossfade, one haptic at stop, single Semantics node.
- **Font**: Nunito (variable, pinned to weight 800) bundled, OFL registered with `LicenseRegistry`.
- **iPhone portrait lock** in `Info.plist` (carried from Phase 0–1 open question 3).
- **Tests**: `selection_test`, `rotation_test`, `labels_test`, `session_bloc_test`, `session_repository_test`, plus `setup_cubit_test` (extended), `router_redirect_test`, `dial_painter_test`, `game_flow_test`, `layout_test`.
- **Gate tooling**: Maestro flows under `tool/maestro/`, `tool/phase2_gate.sh`.
- **Cleanup** of Phase 1 temporaries (section 6).

### Explicitly deferred (not stubbed, not registered, no placeholder UI)
| Item | Phase | What Phase 2 leaves in place |
|---|---|---|
| `Announcer`, native speech, voice notice "Voice unavailable…" | 3 | `speechLine()` in domain; the line is shown as text on Revealed/Challenge. |
| **Replay button** and speaker icon | 3 | `ReplayRequested` event and `SessionActive.replayCount` exist and are tested; no button is rendered. |
| `Prefs`, `PrefsRepository`, `SettingsCubit`, Voice section of the sheet (Announcements, Voice, Speed, Preview) | 3 | Sheet shows Players + Session sections only. |
| Lifecycle wiring (`AppLifecycleListener` → `AppBackgrounded`) | 3 | Event and handler exist and are tested; nothing dispatches it. |
| `NativeBridge`, `LiveActivitySync`, `url.open` → `SessionLinkOpened`, Live Activity status line, URL scheme, widget target | 4 | Event and handler exist and are tested; nothing dispatches it. |
| App icon, README, TestFlight | 5 | `LogoMark` painter exists for in-app use. |

`main.dart` therefore does **not** contain `getIt<LiveActivitySync>().start()` or `getIt<Announcer>().start()` yet.

## 4. Non-goals

- No Swift changes. The two islands are used exactly as Phase 1 built them.
- No new dependencies (no `path`, `collection`, `equatable`, `bloc_concurrency`, `bloc_test`, `mocktail`, `integration_test`, `google_fonts`).
- No use-case classes, no generic base classes, no theme extension system.
- No golden tests (font and platform dependent), no CI.
- No glass imitation in Flutter. No light theme, no landscape, no iPad tuning beyond a max content width.
- No anti-repeat logic, scores, or history.

## 5. Key decisions

Each: problem → options → pick.

**D1. Event concurrency in `SessionBloc`.** Handlers await the repository; interleaving (End during Spin, double Next) could emit onto a stale state. Options: per-handler re-checks after every await; `bloc_concurrency.sequential` (dependency not allowed); one `on<SessionEvent>` with `transformer: (events, mapper) => events.asyncExpand(mapper)`. Pick **`asyncExpand`** — a stdlib one-liner that makes every event strictly sequential, so each handler can read `state` once and trust it. The double-spin guard still emits `spinning: true` before the first await, as the spec requires.

**D2. Persist-then-emit.** Options: optimistic emit then roll back; persist first. Pick **persist first, emit after** for every event except `SpinRequested` (spec: spinning is emitted first, rolled back to `ready` with a failure if the write fails). On any `StorageFailure` the state is re-emitted unchanged with `failure` set, so the user can retry.

**D3. Repository surface.** Options: `saveOutcome` + `saveMode` + `nextRound`; one `saveRound(Session)`. Pick **`saveRound(Session)`** — one `UPDATE` of `round, phase, taker, giver, mode`; the three spec transitions are the same statement. It throws `StorageFailure` unless exactly one row changed. `start(players)` creates the id (`Random.secure`, 32 hex) and timestamp in the data layer so the bloc stays deterministic under `Random(seed)`.

**D4. Failure transport.** Spec: `load()` "returns `Session?` or `CorruptSession`". Options: a result union type; exceptions. Pick **`sealed class Failure implements Exception`**; the repository throws, the bloc catches. No extra result type.

**D5. Start-up without a splash route.** The route list is fixed and has no loading page. Options: add a hidden route; let `/new` flash then redirect; resolve the first state before `runApp`. Pick **await the first non-loading state in `main()`** — the native launch screen covers the few milliseconds of `load()`; the router never sees `SessionLoading`.

**D6. Navigation uses `go` only.** go_router re-checks redirects against the current URI but not against individual imperative pushes (verified). Pick **declarative `go()` for everything**; sheet and dialog are child routes of `/game`. Session end or resume then replaces the whole stack through the redirect, with no orphaned pushed page.

**D7. Edit Players without a new route.** The route list is fixed. Options: a new `/game/players` route; reuse `/new` and `/names` with `?edit=1`. Pick **`?edit=1`** — same pages, title and button label switch on the flag; the redirect lets an active session stay on those two paths only with the flag, in phase `ready`, not spinning. Without the flag an active session on `/new` is sent to `/game`, which is exactly the "session just started" transition.

**D8. End Session from the Resume screen.** Spec A4 names the event `EndConfirmed`; the artboard links Resume → End confirmation. Options: delete on one tap; show the confirmation. Pick **show the confirmation** — the redirect allows `/game/end` in `ResumePrompt`; `GamePage` renders an empty dark page under the scrim in that state; Cancel returns to `/game`, which redirects to `/resume`. A destructive one-tap delete is avoided for about five lines.

**D9. Non-island glass.** The pill, settings button, sheet "Done" and End-confirm card are glass on the canvas, but only two native island kinds are allowed and glass is never faked. Pick **solid Flutter surfaces** (`bgRaised` fill, `line` border, same shapes and sizes). The End-confirm *buttons* (End Session / Cancel) are a real `NativeActionBar`, so they are glass. See open question 1.

**D10. Session sheet in Phase 2.** It shows, top to bottom: grabber; title **"Session"** with a plain text **"Done"** button; section **PLAYERS** with a read-only summary row ("8 players · 5 named", or "8 players" when none are named) and an **"Edit Players ›"** row (enabled only in phase `ready` and not spinning; otherwise dimmed and inert), footnote "Editing between rounds keeps the session; current round resets."; section **SESSION** with a coral **"End Session"** row (inert while spinning). The sheet is content-height, bottom-anchored, scrolls if text is large. **There is no Voice section and no Live Activity status line** — they are added by Phases 3 and 4, not shown disabled.

**D11. Action layout per game phase with the existing island.** The island offers one layout per instance (`stack` or `row`); Revealed needs a choice pair plus a separate Pass, Challenge needs a narrow Pass beside a wide Next Round. Options: change Swift; compose several island instances in Flutter. Pick **compose instances** (Flutter owns layout, spec A7): Revealed = one `row` bar `[Truth, Dare]` + a 104-pt bar `[Pass]`; Challenge = a 104-pt bar `[Pass]` + an expanded bar `[Next Round]`. No Swift change.

**D12. Sheet/dialog over a native island.** A route above `/game` paints a scrim over the game's action bar. Phase 1 advised against Flutter content over an island for cost reasons. Options: hide the game's bars while covered; accept the transient overlay. Pick **accept it** (Flutter composites overlays above platform views; it is only while a sheet is open). Fallback if the gate screenshot shows artefacts: `GamePage` replaces its bars with same-height empty boxes while `state.uri.path != '/game'`.

**D13. Two controllers in `SpinStage`.** Spin (variable duration) and reveal pulse (2 × 600 ms) are sequential and independent. Options: one controller with stitched intervals; two controllers. Pick **two** (`_spin`, `_pulse`), merged into the painter's `repaint` listenable. Still no `setState`.

**D14. Painter derives everything from state + controller value.** The bottle angle is `plan.start + (plan.end − plan.start) · curve(spin.value)` while spinning, else `state.orientation`. `SpinPlan` therefore carries `start` in addition to the spec's `(end, turns, durationMs)`. No mutable fields in the `State` besides the controllers.

**D15. Outcome is hidden while spinning.** The state already holds the persisted outcome during the animation. `SpinStage`, role cards and the Semantics label read the outcome only when `!spinning`.

**D16. `isValidPair` is strict.** Options: distinct seats only (what the SQL CHECK does); distinct **and** opposite. Pick **strict**: giver must be one of `oppositeSeats(n, taker)`. `load()` uses it, so a row that SQL accepts but the rules could never produce is treated as corrupt.

**D17. Name limits.** SQL allows 1–40 characters (`length()` counts code points). `normalizeName` trims, maps empty to `null`, and truncates to 40 **runes**, so a value that passes the domain always passes the CHECK and never splits a surrogate pair. Known ceiling: it can split an emoji ZWJ sequence; marked with a `ponytail:` comment.

**D18. Font file.** Upstream has no static ExtraBold. Options: bundle the variable font (277 KB) and pin `wght` 800; generate a static instance with fonttools (extra tool, modified font). Pick **variable font pinned with `FontVariation('wght', 800)`**. See open question 3.

**D19. Resume status line.** The artboard's "Last round: …" is not derivable (verified). Pick a line about the **current** round: `ready` → "Ready for the next spin."; `revealed` → "This round: {giver} gives {taker} a challenge."; `challenge` → "This round: {giver} gave {taker} a Truth." (or "a Dare").

**D20. Exact player counts on the simulator.** The gate needs N = 59 and 60; Maestro cannot set a native wheel to an exact value. Options: imprecise swipes; a debug affordance in the UI; a build-time initial count. Pick **`int.fromEnvironment('SPINFOLK_INITIAL_COUNT', defaultValue: 8)`** as `SetupState`'s default, clamped to 2–60. One line, no UI, no effect on normal builds. Wheel → cubit was already proven in Phase 1 and is re-checked once in the default build.

**D21. Layout that cannot overflow.** Game page = top bar, a flexible stage (dial sized as a fraction of the free height, then a scrollable panel), and a fixed-height bottom area for the islands. New Game, Add Names and the sheet scroll. Text beside an island is clamped to scale 1.5 to match the island's own Dynamic Type clamp; dial labels ignore text scaling (spec); everything else scales freely. Enforced by `layout_test` at 375 × 667 with scales 1.0, 1.35 and 3.12.

**D22. Portrait only on iPhone.** The dial layout has no landscape design. `UISupportedInterfaceOrientations` → portrait. iPad keys untouched; content is capped at 480 pt wide and centred.

**D23. Setup state after End.** "Clears N players" is a promise. A root `BlocListener` resets `SetupCubit` when the session state becomes `NoSession`, so old names do not reappear on New Game.

**D24. `SessionLinkOpened` on a match.** Spec only says mismatches are ignored. Pick: matching id in `ResumePrompt` behaves like `ResumeConfirmed`; matching id in an active session changes nothing. Dispatch arrives in Phase 4.

## 6. Phase 1 temporaries removed in Phase 2

- `lib/dev/glass_proof_page.dart`, `lib/dev/proof_cubit.dart`, `lib/dev/proof_spin.dart`, `lib/dev/test_painter.dart` (the whole `lib/dev/` folder).
- `tool/phase1_proof.yaml`.
- The `-e '^lib/dev/proof_spin.dart$'` allowlist line in `tool/check_rules.sh`.
- The `// TEMP(phase-1)` `/new` route and its import in `lib/app/router.dart`.
- The `find.text('Players: 8')` expectation in `test/app_smoke_test.dart`.

`docs/plans/phase-0-1/evidence/` stays.

## 7. Contracts fixed in this phase

**State** (sealed, immutable, hand-written `==`/`hashCode`):
`SessionLoading` · `NoSession(notice?)` · `ResumePrompt(session, failure?)` · `SessionActive(session, spinning, spinPlan?, orientation, failure?, replayCount)`.

**Events**: `AppStarted`, `ResumeConfirmed`, `SessionStarted(count, names)`, `SpinRequested`, `SpinAnimationFinished`, `ModeChosen(mode)`, `Passed`, `NextRoundRequested`, `PlayersEdited(count, names)`, `EndConfirmed`, `AppBackgrounded`, `SessionLinkOpened(id)`, `ReplayRequested`.

**Repository**: `load()`, `start(players)`, `saveRound(session)`, `replacePlayers(id, players)`, `end()`; throws `StorageFailure` / `CorruptSession`.

**Redirect** (`sessionRedirect(state, uri)`):

| State | Stays on | Otherwise → |
|---|---|---|
| `SessionLoading` | anything | — |
| `NoSession` | `/new`, `/names` | `/new` |
| `ResumePrompt` | `/resume`, `/game/end` | `/resume` |
| `SessionActive` | `/game`, `/game/settings`, `/game/end`; `/new?edit=1` and `/names?edit=1` only when phase is `ready` and not spinning | `/game` |

**Action-bar item ids** (wire values to the island): `start`, `save`, `resume`, `end`, `cancel`, `spin`, `truth`, `dare`, `pass`, `next`.

**Semantics labels used by Maestro**: dial — "Dial, N players, ready to spin" / "Bottle spinning" / "Taker {label}, Giver {label}"; round pill — "Round R · N players" (one node); settings button — "Session and settings".

## 8. Acceptance checks

Static
- P2-1 `fvm dart run build_runner build --delete-conflicting-outputs` succeeds; generated config registers `Database`, `SessionRepository`, `SessionBloc`, `GoRouter`, `AppNavigator`, `SetupCubit`, `Random`.
- P2-2 `fvm dart format --set-exit-if-changed .` exit 0; `fvm flutter analyze` "No issues found!".
- P2-3 `fvm flutter test` passes; the ten test files of section 3 exist and run.
- P2-4 `tool/check_rules.sh` → `check_rules: OK`; `lib/dev/` and `tool/phase1_proof.yaml` are gone; the only `StatefulWidget` in `lib/` is `spin_stage.dart`.
- P2-5 No dependency added or removed: `git diff pubspec.yaml` shows only the `assets:` and `fonts:` blocks.

Behaviour proven by tests
- P2-6 Selection: for every N in 2…60, taker in range, giver ≠ taker, even N exact opposite, odd N one of the two nearest-opposite seats with both observed, N = 2 giver = 1 − taker; out-of-range N throws.
- P2-7 Rotation: `end ≡ θ(taker) (mod 2π)`, `end − start ∈ [5·2π, 7·2π)`, `turns ∈ {5, 6}`, `durationMs` matches A5.
- P2-8 Bloc: every A4 transition; double `SpinRequested` → one outcome, one write; write failure on spin → `ready` + failure, later spin works; outcome never re-rolled; `AppBackgrounded` while spinning → revealed; `PlayersEdited` rejected outside `ready`; `EndConfirmed` failure keeps the session; corrupt load → `NoSession` with the notice.
- P2-9 Repository on in-memory SQLite: schema A6 created with foreign keys on; round trip; singleton enforced; CHECKs reject impossible rows (including `phase = 'spinning'`); `end()` cascades; corrupt data → `CorruptSession` and empty tables.
- P2-10 `game_flow_test`: the complete loop runs for N = 2, 3, 5, 7, 59, 60 at widget level.
- P2-11 `layout_test`: every screen and game phase at 375 × 667 with text scales 1.0, 1.35, 3.12, N = 60 with a 40-character name, raises no overflow or other exception.

Simulator gate (spec wording in bold)
- P2-12 **Complete loop on simulator for N = 2, 3, 5, 7, 59, 60**: `tool/phase2_gate.sh` runs `tool/maestro/loop.yaml` once per N on the iOS 26.5 simulator; each run starts a session, spins, reveals, chooses Truth, Next Round, spins, Pass, spins, Dare, Pass, kills and relaunches into Resume, resumes, opens the sheet, and ends the session back to New Game. One revealed screenshot per N.
- P2-13 Dial visuals, checked on those screenshots: N ≤ 12 numbered discs with haloed selected seats; N = 59/60 ticks with every fifth labelled; N = 3, 5, 7, 59 show the dotted coral arc; neck (teal) on the taker; bottle straight.
- P2-14 **SE-size + largest text without overflow**: on an iPhone SE (3rd generation) simulator, screenshots of New Game, Add Names, Ready, Revealed (60 players, long name), Challenge, Session sheet and End confirmation at `large`, `extra-extra-extra-large` and `accessibility-extra-extra-extra-large` show no clipped or overlapping content, no overflow stripes; native bar labels are fully visible.
- P2-15 Reduce Motion on: a spin resolves in about 0.6 s by crossfade with the same reveal; no pulse.
- P2-16 Edit Players: from Ready, change the count and one name, save, and the pill and dial show the new count with the round number unchanged.
- P2-17 Sheet and dialog over the game: screenshot shows the scrim covering the game's native bar without artefacts; Cancel and barrier tap return to the game.
- P2-18 **Grep check passes** (same as P2-4, re-run after the simulator work).

Anything that could not be run is reported **NOT VERIFIED** with the reason.

## 9. Risks

| Risk | Likelihood | Handling |
|---|---|---|
| First real use of `sqflite` on iOS through SwiftPM fails to build or open. | Low–medium | It is the first step after the domain. Stop and report the build output; do not add CocoaPods or another storage package. |
| `sqflite_common_ffi` on the test host needs the `sqlite3` native-asset hook (may download on first run). | Medium | Run the repository test early. If it cannot run offline, report it; do not swap dependencies. |
| Variable font ignores `FontWeight` and renders at Regular. | Medium | `FontVariation('wght', 800)` is set explicitly in the one `Tokens.numeral` style; verify on a screenshot against the artboard. |
| Maestro cannot see Flutter semantics, or `stopApp`/relaunch behaves differently on this Xcode. | Low–medium | Read the Phase 0–1 report first and reuse what worked there. Do not add `ensureSemantics()` to production code without asking. Fall back to NOT VERIFIED + manual script. |
| Scrim over a glass island shows artefacts or blocks touches after dismissal. | Low–medium | Fallback in D12. |
| Platform view recreated on phase change flashes for a frame. | Medium, cosmetic | Ready ↔ Spinning share one instance (config update). Other transitions coincide with the 320 ms panel change. Report if visible. |
| Native bar text clipped at `.accessibility2` in the fixed heights. | Medium | Bar heights scale with text (factor clamped 1.0–1.5). Checked in P2-14. |
| 60 `TextPainter` layouts per frame in tick mode. | Low | Only 12 labels + 2 selected are text; painters are built once per painter instance, not per frame. |
| `SPINFOLK_INITIAL_COUNT` left in a release command by accident. | Low | Clamped to 2–60; only changes the wheel's starting value. |
| Dial resize between phases looks jumpy. | Low, cosmetic | `AnimatedContainer` 320 ms; disabled under Reduce Motion. |
| Phase 0–1 branch still moving while Phase 2 starts. | Medium | Step 0 of the guidelines: start only from a green `phase-0-1` tip; re-read the listed files. |

## 10. Open questions

None block the work; each has a default that will be built unless the owner says otherwise.

1. **Non-island glass (D9).** Round pill, settings button, sheet "Done" and the End-confirm text card are solid surfaces, not glass, because only two native island kinds are allowed. If these must be glass, that is a spec change (a third island kind, or a larger native region) and should be decided before Phase 2 UI is polished.
2. **Dare sentence.** No approved copy. Default: "**{giver}** gives **{taker}** a dare, out loud." (Truth stays "…asks … a question, out loud.")
3. **Font (D18).** Variable Nunito (277 KB, all weights) pinned to 800 instead of a static ExtraBold file, because upstream publishes no static file. Say so if a static instance should be generated instead.
4. **Resume line (D19).** Shows the current round's status rather than "Last round", because the fixed schema keeps no history.
5. **Test hook (D20).** `SPINFOLK_INITIAL_COUNT` compile-time constant lives in production code. Say so if it should be removed after the gate.

## Owner decisions (2026-11-22) — do not reopen
- Non-island glass elements (round pill, settings button, sheet Done, End-confirm text card): solid `bgRaised` surfaces, same shapes. Only picker + action bar are native glass.
- All open-question defaults approved: Dare line "{giver} gives {taker} a dare, out loud."; Nunito variable font pinned to wght 800; Resume shows current round status; `SPINFOLK_INITIAL_COUNT` compile-time test hook; iPhone portrait lock.
- Phase 0–1 committed and pushed on branch `phase-0-1`; Phase 2 continues on that branch.
