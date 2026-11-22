# Spinfolk — Phase 2b (Flow v2 · History + adaptive native glass): Technical PRD

Date: 2026-11-22 · Spec: `docs/spec-v2.md` (architecture fixed; amended by §6 of this file) · Builds on: `docs/plans/phase-2/` at commit `e425351` · Companion: `guidelines.md` in this folder.

## 1. Problem

Phase 2 ships one linear loop: New Game → Game → End deletes everything. The owner added a v2 design page (`docs/design/project/UserFlow.dc.html`, `Interactions.dc.html` and 11 screen artboards) that turns the app into a hub with memory:

- **Home** is the root: in-progress card with Resume, New game, Recent games.
- **New game** gets quick-count chips (4/6/8/10/12), the wheel, and a live seat preview.
- **Ready** gets flick-to-spin and a tappable round pill / "LAST" card that open a **Round log** sheet.
- **End Session** archives the game and shows an **End summary** with "Play again · same players".
- **History**: list grouped by date, game detail, swipe-to-delete, delete confirmation, 5-second Undo toast, empty state.

The owner also asked: "for more native glass UI look use Adaptive Platform UI plugin if spm is enabled and available". That relaxes the Phase 2 owner decision that only the picker and the action bar are native glass.

Phase 3 (speech, prefs, lifecycle) and Phase 4 (Live Activity) are planned in parallel and build on this branch. Phase 2b is Flow v2 plus glass only.

## 2. Verified facts (checked 2026-11-22 by reading code, not assumed)

| Fact | Source |
|---|---|
| Branch `phase-2` head is `e425351`. The 13 v2 artboards are untracked files in `docs/design/project/`. | `git log`, `git status` |
| Router is redirect-driven by a pure `sessionRedirect(state, uri)`; `AppNavigator` only calls `GoRouter.go`; sheets and dialogs are `CustomTransitionPage` routes built by `_overlay`, whose barrier tap is hard-wired to `nav.game()`. | `lib/app/router.dart`, `lib/app/app_navigator.dart` |
| States: `SessionLoading`, `NoSession(notice)`, `ResumePrompt(session, failure)`, `SessionActive(...)`. One sequential event handler. `_start` only runs from `NoSession`; `_end` deletes. | `lib/features/session/presentation/bloc/` |
| DB v1: `session` (singleton row, CHECKs) and `player`; `repo.start` deletes any old session inside its transaction; `repo.end` is `DELETE FROM session`. `openSessionDb` deletes the whole file on a `DatabaseException` at open. No `onUpgrade` yet. | `lib/features/session/data/` |
| `GamePage` already drops its native bars while another route covers `/game`, because the simulator showed native bars painting over the sheet scrim (Phase 2 deviation D12). | `game_page.dart` lines 26–38, `phase-2/prd.md` |
| `ActionBarView.swift` buttons are bottom-aligned with fixed minimum heights (primary 64, others 50), no haptics, Dynamic Type clamped at `.accessibility2`. `PickerView.swift` rows read "N players". | `ios/Runner/Native/` |
| The round pill, settings button and sheet "Done" are flat Flutter surfaces today. | `game_page.dart`, `settings_sheet_page.dart` |
| `adaptive_platform_ui 1.0.2`: SwiftPM manifest present (iOS 15+), plugin class `AdaptivePlatformUiPlugin`, runtime deps `flutter` + `foldable ^1.0.3` (`foldable 1.0.5` also ships `ios/foldable/Package.swift`, iOS 15+, and pulls `plugin_platform_interface`). | unpacked source, `~/.pub-cache` |
| `AdaptiveButton` picks its path in Dart: iOS 26+ → native `IOS26Button`; iOS below 26 → a flat `CupertinoButton` with a 15 % tint (no material). | `lib/src/widgets/adaptive_button.dart` |
| `IOS26Button` used directly creates a `UiKitView` on every iOS version. Its Swift side uses `UIButton.Configuration.glass()` / `.prominentGlass()` on iOS 26 and falls back to `.plain()` + `UIBlurEffect(.systemUltraThinMaterial)` / `.tinted()` + `.systemMaterial` below 26. That matches spec A1-9. | `ios26_button.dart`, `iOS26ButtonView.swift` |
| `IOS26Button` hard-codes `UIImpactFeedbackGenerator(style: .medium)` on every tap, fixed fonts 13/15/17 (no Dynamic Type), no accessibility label for symbol-only buttons, and updates a changed label with `setTitle` on a configuration-based button. | `iOS26ButtonView.swift` |
| `AdaptiveBlurView` uses `BackdropFilter` below iOS 26 and plain `UIBlurEffect` material (not Liquid Glass) on 26. `AdaptiveAlertDialog` uses `showCupertinoDialog` / `showDialog` + `Navigator.pop`. `AdaptiveSnackBar` uses `Overlay` / `ScaffoldMessenger`. The package has no exported Liquid Glass container. | package `lib/src/widgets/` |
| The package's Dart files import `package:flutter/material.dart` and `cupertino.dart`. That is dependency code, outside `lib/`; spec A1-2 accepts dependency deprecation infos. | package source |
| `Info.plist` forces `UIUserInterfaceStyle = Dark`, so the package's `platformBrightness` sync yields dark. Deployment target 17.0. No Podfile. | `ios/Runner/Info.plist`, `project.pbxproj` |
| `material_ui 1.11.1` exports `Icons`; `uses-material-design: true` is set. | `pubspec.yaml`, pub cache |
| **Not verified:** that `adaptive_platform_ui 1.0.2` resolves and builds with Flutter 3.50.1 in this project. Step 1 of the guidelines is that gate. | — |

## 3. Scope

### In
1. Dependency `adaptive_platform_ui: 1.0.2` behind one wrapper, `GlassButton`; new glass rule (§6.1).
2. DB schema v2 (additive migration): live round log, finished-game history, soft delete.
3. `SessionBloc`: round logging, archive on End and on "start over an in-progress game", `SessionSummary` state.
4. `HistoryRepository` + `HistoryCubit` (list, delete, clear all, undo, purge).
5. Router: `/` Home hub, `/history`, `/history/:id`, confirm overlays, `/game/log`, `/summary`. `ResumePage` is deleted.
6. Screens per artboards: Home, NewGame2, Ready2 changes, RoundLog sheet, EndSummary, History, HistorySwipe, DeleteConfirm, HistoryUndo, HistoryDetail, HistoryEmpty.
7. Flick-to-spin on the bottle.
8. Sheets (Round log, Session) on a shared frame with medium/large detents and drag-to-dismiss.
9. Tests, `tool/check_rules.sh` additions, deferred Maestro flows, spec amendment block.

### Deferred (not built, not stubbed)
- Everything in Phase 3 and 4: speech, Replay, prefs, voice settings rows, `AppLifecycleListener`, Live Activity. Seams are listed in §10.
- Native switch/slider from the package (Phase 3 settings rows).
- Simulator and Maestro runs (owner decision). Flows are written and marked deferred.

## 4. Non-goals

- No package widgets other than `IOS26Button` in this phase (no `AdaptiveApp`, scaffold, toolbar, tab bar, alert dialog, snackbar, blur view, popup or context menu, text fields).
- No glass containers: cards, sheets, the toast body and confirm text cards stay solid Flutter surfaces.
- No per-row or per-seat native views.
- No resting "swipe open" state with a tappable 96-pt Delete button (see D9).
- No hero hand-off between the Home mini dial and the game dial, no staggered role-card rise (Interactions "Hub → game hand-off" and "Reveal choreography"). Both are motion polish that cannot be judged without a simulator; Revealed is not a v2-changed screen.
- No flick-direction or flick-speed effect on the spin.
- No date/number localisation package; labels are English, hand-formatted.
- No pagination of history.
- No change to selection math, `spinPlan`, or the persisted-before-animation rule.

## 5. Key decisions

Each: problem → options → pick, one-line reason.

**D1. What moves to `adaptive_platform_ui`.**
Options: (a) nothing, keep two islands; (b) hybrid: package for small chrome buttons, own islands for bars and wheel; (c) replace `NativeActionBar` with package buttons.
Pick **(b)**. (a) ignores an explicit owner request. (c) loses Dynamic Type, the equal-weight choice pair in one view, label updates that are known to work, and adds a medium haptic to Spin/Truth/Dare, which breaks the haptic map ("Stop: medium (once)").

| Element | Renders with | Why |
|---|---|---|
| Wheel | `NativePicker` (own) | Proven; package has no wheel. |
| Spin, Truth/Dare, Pass, Next, Start session, Resume game, New game, Play again, Done (summary), Start a game, confirm buttons | `NativeActionBar` (own) | Proven sizes, a11y, no stray haptics. |
| Quick-count chips 4/6/8/10/12 | `NativeActionBar` row, new styles `chip` / `chipOn` | One native view instead of five in a scroll view; exact "selection" haptic from Dart. |
| Round pill, settings (···) button, Home history button, sheet "Done", toast "Undo" | `GlassButton` → package `IOS26Button` | Small chrome that was flat in Phase 2; this is the "more native glass" the owner asked for. |
| Settings switch / slider | package `AdaptiveSwitch` / `AdaptiveSlider` — **Phase 3** (its D14) | Not in 2b. Native on iOS 26+, standard Cupertino controls below; neither is glass, so nothing is faked. |
| Cards, sheets, toast body, confirm text card, list rows, seat preview | solid Flutter | No real glass container available; glass is never faked. |

**D2. `IOS26Button`, not `AdaptiveButton`.** `AdaptiveButton` draws a flat Cupertino button on iOS 17–25. `IOS26Button` keeps a native view there with real system material. Pick `IOS26Button` — same shapes and a real material on every supported iOS, as spec A1-9 requires.

**D3. `GlassButton` draws its own label.** Options: package title mode (fixed 13/15/17 system font, no intrinsic width in Flutter); package child mode (its `Center` expands to the full width under bounded constraints); own `Stack` over an empty-label `IOS26Button`. Pick the **own `Stack`**: width comes from the Flutter content, text can be Nunito and mixed weight, and no label ever has to be pushed to the native side.

**D4. Schema v2 shape.**
Options: (a) additive: keep `session`/`player`, add `round_log` and three history tables, copy on End; (b) unify: drop the singleton, add `ended_at` to `session`, history is "ended sessions".
Pick **(a)**. (b) needs a table rebuild inside sqflite's upgrade transaction with foreign keys on (drop/rename with cascade hazards) and rewrites every proven Phase 2 query. (a) cannot lose v1 data and costs three `INSERT … SELECT` statements on End.

**D5. When a round is logged.** Options: on Next/Pass only (then End during `challenge` needs a special case); upsert when the result becomes known. Pick **upsert**: `ModeChosen` writes truth/dare for the current round, `Passed` writes or overwrites `pass`. Same transaction as the session `UPDATE`. `NextRoundRequested` writes nothing. "Rounds" everywhere in v2 means logged rounds.

**D6. Delete + undo.** Options: soft delete (`deleted_at`) then purge; deferred delete held in memory; hard delete and re-insert on undo. Pick **soft delete** — it is what the interaction spec states, undo is one small `UPDATE`, and a kill inside the 5 s still deletes (purge runs at next DB open). Purge triggers in 2b: toast timer, the next delete, DB open. "App backgrounds" is wired in Phase 3 through `HistoryCubit.purgeNow()`.

**D7. Router shape.** Options: keep `/new` as root plus `/resume`; `/` Home hub. Pick **Home hub**: `NoSession` and `ResumePrompt` both resolve to `/` (card shown only for `ResumePrompt`); history and setup are child routes of `/` so the system back-swipe works; `SessionActive` still forces `/game…`; a new `SessionSummary` state forces `/summary`. Still one pure redirect function. `ResumePrompt` keeps its name to limit churn for Phase 3/4.

**D8. Summary as bloc state.** Options: imperative navigation after End; a `SessionSummary(game)` state. Pick the **state** — blocs never navigate, and a relaunch on the summary lands on Home with the game already in History.

**D9. Swipe-to-delete widget.** Options: `Dismissible` (framework); custom swipe row with a resting open state (needs a new `StatefulWidget` + controller per row); a slidable package. Pick **`Dismissible`**: threshold 0.6, coral "Delete" background, 250 ms collapse, haptic at the threshold, VoiceOver custom action. The resting tappable Delete button is not built (open question 2).

**D10. Undo toast.** No `SnackBar`. An inline widget on `HistoryPage` driven by `HistoryState.pending`. The 5 s clock is a `Timer` in the cubit; the countdown ring is a `TweenAnimationBuilder` (no new `StatefulWidget`).

**D11. Flick-to-spin fairness.** Options: velocity scales turns/duration; velocity ignored. Pick **ignored**, as the interaction spec says. The flick adds the existing payload-free `SpinRequested()`; `pickRoles` and `spinPlan` are untouched, so no gesture value can reach the outcome. While dragging, the bottle follows the finger through a widget-local angle; on a flick the animation starts from that visual angle and ends at the unchanged `plan.end`. A slow release animates back in 180 ms. Direction is ignored (the plan always turns clockwise).

**D12. Zero-round games.** A game with no logged round is not archived (End goes straight to Home; "start over" just replaces it). Reason: a "0 rounds" history row has nothing to show. Open question 4.

**D13. Native views under another route.** Generalise the Phase 2 fallback: only the top route shows native views. A covered page drops its action bars and renders `GlassButton` flat. One shared helper.

**D14. Sheets.** Options: keep the Phase 2 content-sized sheet; `DraggableScrollableSheet` (framework). Pick **`DraggableScrollableSheet`** in one shared `SheetFrame` used by Round log and Session: detents 0.55 and 0.93, grabber, drag below the lower detent dismisses. Phase 3 adds its rows inside the same frame.

**D15. Date and duration text.** No `intl`. Pure functions with `now` and `h24` passed in.

## 6. Contracts fixed in this phase

### 6.1 Glass rule (replaces spec A1-12 and "exactly two native islands")

1. Glass is real or absent. Liquid Glass and material come only from native views. `BackdropFilter`, `ImageFilter.blur`, shaders and the package's `AdaptiveBlurView` are banned.
2. Three native view kinds in 2b: `NativePicker`, `NativeActionBar` (own SwiftUI) and `GlassButton` (wraps `IOS26Button`). Phase 3 may add `AdaptiveSwitch` / `AdaptiveSlider` for the settings rows. Nothing else from the package.
3. `package:adaptive_platform_ui` is imported only under `lib/platform/`, always with a `show` clause. Other code reaches package widgets through that folder (a wrapper, or a one-line re-export).
4. Budget: at most 4 native views on the visible top route (Game: pill, settings, up to 2 bars). None inside list rows or per seat.
5. Only the top route shows native views (D13).
6. Flutter content is never stacked over a picker or an action bar. Only `GlassButton` carries a Flutter-drawn label over its capsule.
7. Dialogs, sheets and toasts stay routes or inline state.
8. Accepted package behaviour: a medium impact haptic on each `GlassButton` tap (open question 1).

### 6.2 Session states and events

```
SessionLoading | NoSession(notice?) | ResumePrompt(session, failure?)
| SessionActive(session, spinning, spinPlan?, orientation, failure?, replayCount)
| SessionSummary(game)                                            // new
```
New event: `SummaryDismissed`. Changed handlers:

| Event | From | Effect |
|---|---|---|
| `SessionStarted` | `NoSession`, `ResumePrompt`, `SessionSummary` | `repo.start` archives a stored session that has ≥ 1 logged round, deletes it, inserts the new one (one transaction). Failure: `NoSession(notice)` (also from Summary) or `ResumePrompt(session, failure)`. |
| `ModeChosen` | `revealed` | Session → challenge; log upsert (truth/dare). |
| `Passed` | `revealed`, `challenge` | Log upsert `pass`; round + 1. |
| `NextRoundRequested` | `challenge` | Round + 1; no log write. |
| `EndConfirmed` | `SessionActive`, not spinning | `repo.end(session)` → `SessionSummary(game)`, or `NoSession()` when nothing was archived. No longer accepted from `ResumePrompt`. |
| `SummaryDismissed` | `SessionSummary` | `NoSession()`. |

`Session` gains `log: List<RoundEntry>`; `RoundEntry(round, taker, giver, result)`; `RoundResult { truth, dare, pass }`.

### 6.3 Routes

| Path | Page | Allowed in |
|---|---|---|
| `/` | `HomePage` | `NoSession`, `ResumePrompt` |
| `/new`, `/names` | setup | hub states; `SessionActive` only with `?edit=1`, phase ready, not spinning |
| `/history`, `/history/clear` (overlay), `/history/:id`, `/history/:id/delete` (overlay) | history | `NoSession`, `ResumePrompt`, `SessionSummary` |
| `/summary` | `SummaryPage` | `SessionSummary` |
| `/game`, `/game/settings`, `/game/log`, `/game/end` (overlays) | game | `SessionActive` |

Anything else redirects to `/` (hub states), `/summary`, or `/game`.

### 6.4 SQLite v2 (`PRAGMA user_version = 2`; v1 tables unchanged)

```sql
CREATE TABLE round_log (
  session_id TEXT    NOT NULL REFERENCES session(id) ON DELETE CASCADE,
  round      INTEGER NOT NULL CHECK (round >= 1),
  taker      INTEGER NOT NULL CHECK (taker BETWEEN 0 AND 59),
  giver      INTEGER NOT NULL CHECK (giver BETWEEN 0 AND 59),
  result     TEXT    NOT NULL CHECK (result IN ('truth','dare','pass')),
  CHECK (taker <> giver),
  PRIMARY KEY (session_id, round)
);
CREATE TABLE game (
  id           TEXT    PRIMARY KEY,
  started_at   INTEGER NOT NULL,
  ended_at     INTEGER NOT NULL CHECK (ended_at >= started_at),
  player_count INTEGER NOT NULL CHECK (player_count BETWEEN 2 AND 60),
  deleted_at   INTEGER
);
CREATE TABLE game_player (
  game_id TEXT    NOT NULL REFERENCES game(id) ON DELETE CASCADE,
  seat    INTEGER NOT NULL CHECK (seat BETWEEN 0 AND 59),
  name    TEXT    CHECK (name IS NULL OR length(name) BETWEEN 1 AND 40),
  PRIMARY KEY (game_id, seat)
);
CREATE TABLE game_round (
  game_id TEXT    NOT NULL REFERENCES game(id) ON DELETE CASCADE,
  round   INTEGER NOT NULL CHECK (round >= 1),
  taker   INTEGER NOT NULL CHECK (taker BETWEEN 0 AND 59),
  giver   INTEGER NOT NULL CHECK (giver BETWEEN 0 AND 59),
  result  TEXT    NOT NULL CHECK (result IN ('truth','dare','pass')),
  CHECK (taker <> giver),
  PRIMARY KEY (game_id, round)
);
```
- `onUpgrade` from 1 runs exactly these four statements. No data is transformed.
- Archive = one transaction: three `INSERT … SELECT` (with `MAX(?, started_at)` for `ended_at`) then `DELETE FROM session` (cascades `player`, `round_log`).
- `onOpen` purges `game` rows with `deleted_at IS NOT NULL`.
- Seats in log rows are checked against 0–59 only: Edit Players can shrink the circle mid-game, and old rows stay. Labels fall back to `P{n}`.

### 6.5 Repositories

```dart
abstract interface class SessionRepository {
  Future<Session?> load();                                    // now includes log
  Future<Session> start(List<Player> players);                // archives then replaces
  Future<void> saveRound(Session s, {RoundEntry? log});       // log != null → same transaction
  Future<void> replacePlayers(String id, List<Player> players);
  Future<GameRecord?> end(Session s);                         // null when nothing archived
}
abstract interface class HistoryRepository {
  Future<List<GameRecord>> games();                           // not deleted, newest first
  Future<void> softDelete(List<String> ids, int atMs);
  Future<void> restore(List<String> ids);
  Future<void> purgeDeleted();
}
```

## 7. Acceptance checks

Static (must pass in this phase):

- **P2b-1** `fvm flutter pub get` resolves `adaptive_platform_ui 1.0.2`; `fvm flutter build ios --simulator --debug` succeeds with it linked through SwiftPM; `ios/Podfile` still absent.
- **P2b-2** Format, analyze, build_runner, `tool/check_rules.sh`, `fvm flutter test` all clean. `grep -rn "package:adaptive_platform_ui" lib/` hits only `lib/platform/`. `extends StatefulWidget` in `lib/` still has exactly one hit.
- **P2b-3** Migration test: a v1 file with a session and players opens as v2 with the session intact, the four new tables present, `user_version = 2`.
- **P2b-4** Repository tests: log upsert in the same transaction; End archives and returns the record; End with no logged round archives nothing and returns null; start over a stored session archives it; soft delete hides, restore shows, purge cascades; soft-deleted rows are gone after reopen; CHECKs refuse bad `result` and `taker = giver`.
- **P2b-5** Bloc tests: every row of §6.2, including Pass after Truth overwriting the log entry, and failures keeping the previous state.
- **P2b-6** Redirect test covers every state × path cell of §6.3; no cell returns a location it rejects.
- **P2b-7** Cubit tests: `delete` emits the shortened list before its first await; Undo restores; after 5 s the rows are purged and `pending` is empty; a second delete purges the first; a failed soft delete restores the list and sets `failure`.
- **P2b-8** Fairness: with the same seed, a flick and a Spin tap produce the same stored outcome; `SpinRequested` has no fields; a release below 3 rad/s leaves phase `ready`.
- **P2b-9** Flow tests: launch with nothing stored → Home without card; with a stored session → card + Resume; New game over an in-progress game archives it; chip tap sets the count; full loop → End → summary numbers match the log → Play again starts round 1 with the same names; Done → Home shows the game under Recent; History swipe delete → toast → Undo; delete from detail → confirm → toast; Clear all.
- **P2b-10** Layout tests (375×667 at 1.0/1.35/3.12 and 320×568 at 1.0) visit every new screen with 60 players and 40-character names without overflow exceptions.

Deferred to the end-of-project simulator gate (written now, not run):

- **P2b-S1** `GlassButton` renders Liquid Glass on iOS 26 and material on iOS 18; label legible; prominent Undo is white with navy text.
- **P2b-S2** No jank during a 10 s spin with pill + settings + bar on screen.
- **P2b-S3** VoiceOver reads the Flutter labels of `GlassButton`s, "Delete game" custom action works, chips announce "N players, selected".
- **P2b-S4** Wheel animates to a chip value; sheets snap to both detents and dismiss by drag; a covered page shows no native view through the scrim.
- **P2b-S5** Maestro flows `tool/maestro/loop.yaml` (updated) and `tool/maestro/history.yaml`.

## 8. Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Package does not resolve or build on Flutter 3.50.1 / Xcode in use. | Medium (unverified) | Step 1 is a hard gate before any other work. Fallback: `GlassButton` keeps only its flat path (one file); the rest of the plan is independent. Report and stop for an owner decision. |
| Flutter-drawn label over a native capsule does not composite as expected (Phase 2 saw native bars over a scrim). | Low–medium | Same mechanism the package's own child mode uses. Flat path exists per button (`flat: true`). Checked at P2b-S1. |
| Extra native views cost frames during the spin. | Low | Budget of 4; pill and settings are static and do not overlap the dial. P2b-S2. |
| Upgrade or archive bug loses data. | Low | Additive migration; archive in one transaction; tests P2b-3/4. App is 0.1.0+1 with no distributed builds. |
| `openSessionDb` deletes the file when open throws; that now also deletes history. | Low | Unchanged in 2b (an unreadable file has no recoverable history). Noted for the owner. |
| `Dismissible` asserts if the row is still in the tree after dismissal. | Medium if done wrong | `HistoryCubit.delete` emits before its first await; test P2b-7. |
| An in-progress v1 session has no log for rounds already played. | Certain, dev installs only | Log starts at the current round. |
| Package symbol button exposes "ellipsis"-style default VoiceOver names. | Medium | `GlassButton` wraps in `Semantics(excludeSemantics: true, label, onTap)`. P2b-S3. |
| Haptic at swipe threshold is `heavyImpact`, not "rigid" (Flutter has no rigid). | Certain | Accepted approximation. |

## 9. Open questions

None block the work; the default is built unless the owner says otherwise.

1. **Haptics on package buttons.** `IOS26Button` fires a medium impact on every tap. The haptic map says nothing but picker/chips, grab, stop, swipe threshold and errors vibrates. Default: accept it for the five chrome buttons. Alternative: replace the package inside `GlassButton` with a ~50-line own SwiftUI capsule (same glass, no haptic); one file changes.
2. **Swipe-to-delete resting state.** Built as full-swipe delete past 60 % with the coral "Delete" behind the row. The artboard's resting 96-pt tappable Delete button is not built. Alternative: a custom swipe row (second allow-listed `StatefulWidget`, ~120 lines).
3. **Glass cards.** The Home in-progress card, confirm text card and toast body are glass on the artboards and solid here, because no real glass container exists in the package or the app. Alternative: a ~20-line passive own island behind Flutter content, to be judged on a simulator.
4. **Zero-round games are not saved** (D12). Alternative: always archive.
5. **Copy without an artboard.** End confirmation: "Saves N players and R rounds to History. Voice settings stay. Lock Screen activity ends too." Clear all: "Clear all history?" / "N games and their round logs are removed from this iPhone. You can undo for a few seconds." / button "Clear all".
6. **Deferred polish** (§4): hero hand-off, staggered reveal, flick direction.

## 10. Seams for Phase 3 and Phase 4

- **Lifecycle (Phase 3):** 2b creates no `AppLifecycleListener`. Phase 3 creates it (its D9) and, on hide, calls `HistoryCubit.purgeNow()` next to `SessionBloc.add(AppBackgrounded())`.
- **Settings sheet (Phase 3):** the sheet is still a Flutter route in `settings_sheet_page.dart`; its private `_Label`, `_Card`, `_Row`, `_Divider` are kept. Add the VOICE section inside the `Column` that `SheetFrame` receives. For `AdaptiveSwitch` / `AdaptiveSlider`, add `lib/platform/adaptive_controls.dart` containing only `export 'package:adaptive_platform_ui/adaptive_platform_ui.dart' show AdaptiveSwitch, AdaptiveSlider;` and import that file (glass rule 3; `tool/check_rules.sh` enforces it). Two more native views fit the budget: the sheet's top route then holds Done + switch + slider.
- **Announcer (Phase 3):** unchanged triggers. `SessionSummary` and `ResumePrompt` never speak.
- **Last round (Phase 4):** it is in bloc state as `SessionActive.session.log.last` (`RoundEntry`; `result` is `truth`, `dare` or `pass`); empty log means none. No repository call is needed.
- **Live Activity (Phase 4):** "session ended" is now `SessionActive → SessionSummary` (rounds = `game.rounds.length`) or `→ NoSession`. A new session id after `SessionStarted` from `ResumePrompt`/`SessionSummary` means end the old activity, start a new one. `activity.end` text: "Session ended · N rounds".
- **Deep link:** `SessionLinkOpened` still resumes only from `ResumePrompt` with a matching id.

## Owner decisions (2026-11-22) — do not reopen
- All open-question defaults in this PRD approved as written.
- Glass: adaptive_platform_ui IOS26Button for the 5 chrome buttons (accept its medium haptic); cards/toast/confirm cards solid.
- History swipe: full-swipe Dismissible delete + undo toast (no resting Delete button).
- Zero-round games are not saved to History.
- Voices follow device language; mode line spoken only on Replay; player names shown on Lock Screen; after a pass the Live Activity shows no roles.
- Evidence screenshots stay out of git; simulator/Maestro automation runs once after all phases.
