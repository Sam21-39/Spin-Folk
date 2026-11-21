# Spinfolk — Phase 2b: Implementation Guidelines

Read `prd.md` (this folder), `docs/spec-v2.md`, and the v2 artboards first: `docs/design/project/UserFlow.dc.html` and `Interactions.dc.html`, then `Home`, `NewGame2`, `Ready2`, `RoundLog`, `EndSummary`, `History`, `HistorySwipe`, `DeleteConfirm`, `HistoryUndo`, `HistoryDetail`, `HistoryEmpty`. Decision ids (D1…) and contract sections (§6.x) refer to `prd.md`. Sizes, colours and copy not stated here come from the artboard's inline styles; tokens come from `lib/app/tokens.dart`.

## 0. Ground rules

- All Phase 2 ground rules still apply: every command through `fvm`, run from `/Users/sp/Dev/Games/Spin-Folk`; no `setState`; no `showDialog` / `showModalBottomSheet` / `SnackBar` / `ScaffoldMessenger` / `BackdropFilter`; Material import is `package:material_ui/material_ui.dart`; blocs and cubits never see `BuildContext` and never navigate; navigation only through `AppNavigator`, which only calls `GoRouter.go`.
- **One new dependency:** `adaptive_platform_ui: 1.0.2`. Nothing else. No `intl`, no slidable package.
- **Swift changes are limited to** `ios/Runner/Native/ActionBarView.swift` and `PickerView.swift` as written in step 6. No Xcode project edits, no Podfile, no `DEVELOPMENT_TEAM`.
- `spin_stage.dart` stays the only `StatefulWidget` in `lib/`. Framework widgets that are stateful inside (`Dismissible`, `DraggableScrollableSheet`, `TweenAnimationBuilder`, `AnimatedSwitcher`) are fine.
- Every page must render safely for one frame in a state it does not expect: return `const SizedBox.shrink()` (inside its `Scaffold` where it has one).
- Do not build anything listed under "Deferred" or "Non-goals" in `prd.md`.
- Report honestly; paste real output; anything not run is **NOT VERIFIED** with the reason. Simulator and Maestro runs are deferred by owner decision: write the flows, do not run them.
- Git: `git switch -c phase-2b e425351`. The 13 untracked `docs/design/project/*.dc.html` files and this plan folder belong to the first commit. Commit only when the orchestrator or owner says so; never push. Evidence stays out of git (`docs/plans/*/evidence/` is ignored).

Start condition:
```sh
git switch phase-2 && git status --short        # only the untracked design files and docs/plans/phase-2b/
fvm dart run build_runner build --delete-conflicting-outputs
fvm dart format --set-exit-if-changed . && fvm flutter analyze && fvm flutter test && tool/check_rules.sh
git switch -c phase-2b
```
If any of these fail, stop and report. Then re-read the files this plan quotes, because the code wins over this file: `lib/app/{app,router,app_navigator,ui,tokens}.dart`, `lib/features/session/**`, `lib/features/game/presentation/**`, `lib/features/setup/presentation/**`, `lib/features/settings/presentation/pages/settings_sheet_page.dart`, `lib/platform/*`, `ios/Runner/Native/*.swift`, `test/support/*`.

Step order: 1 dependency gate → 2 domain → 3 data → 4 bloc + cubit → 5 router/navigator/app/main → 6 platform (Dart + Swift) + rules → 7 shared UI → 8 pages → 9 widget tests → 10 Maestro (deferred) + spec amendment → 11 verify + report. Run the static block (§11) after steps 3, 4, 5 and 8.

---

## 1. Dependency gate (do this before anything else)

`pubspec.yaml`, under `dependencies`, after `shared_preferences`:
```yaml
  adaptive_platform_ui: 1.0.2
```
```sh
fvm flutter pub get
grep -nE "adaptive_platform_ui|foldable|plugin_platform_interface" pubspec.lock
fvm flutter build ios --simulator --debug
ls ios/Podfile 2>/dev/null        # must print nothing
git status --short ios/           # expect no tracked changes
```
Expected: `adaptive_platform_ui 1.0.2`, `foldable 1.0.x` in the lock; build succeeds; `ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift` lists `adaptive_platform_ui` and `foldable`.

**If pub get or the build fails: stop and report the exact error.** Do not pin another version, patch the package, or add CocoaPods. (Fallback for the owner to choose: `GlassButton` with its flat path only.)

---

## 2. Domain (pure Dart)

### `lib/features/session/domain/entities/session.dart` — extend
```dart
enum RoundResult { truth, dare, pass } // .name is the SQL value

final class RoundEntry {
  const RoundEntry({required this.round, required this.taker, required this.giver, required this.result});
  final int round, taker, giver;
  final RoundResult result;
  // hand-written == / hashCode over all four fields
}
```
`Session`:
- New field `final List<RoundEntry> log;` (constructor default `const []`), ascending by round.
- `==` / `hashCode` include `log` (same loop style as `players`).
- `isValid` additionally requires, for every entry: `round >= 1`, `round <= this.round`, `taker != giver`, seats within 0–59, and strictly increasing rounds.
- `_copy` gains `List<RoundEntry>? log` (kept when omitted).
- `chose(Mode m)`: as now, plus `log: _logged(m == Mode.dare ? RoundResult.dare : RoundResult.truth)`.
- New `passed()`: `_copy(round: round + 1, phase: Phase.ready, log: _logged(RoundResult.pass))`.
- `nextRound()` unchanged (log kept).
- `withPlayers` keeps the log.
- Private `_logged(RoundResult r)`: `[...log.where((e) => e.round != round), RoundEntry(round: round, taker: outcome!.taker, giver: outcome!.giver, result: r)]`. The entry for the current round is therefore always last.

### `lib/features/session/domain/entities/game_record.dart` — new
```dart
final class GameRecord {
  const GameRecord({required this.id, required this.startedAtMs, required this.endedAtMs,
      required this.players, required this.rounds});
  final String id;
  final int startedAtMs, endedAtMs;          // epoch ms UTC
  final List<Player> players;                // index == seat
  final List<RoundEntry> rounds;             // ascending
  int get playerCount => players.length;
  int get durationMs => endedAtMs - startedAtMs;
  // ==: id, endedAtMs, players.length, rounds.length (a record never changes after archive)
}

final class GameStats {
  const GameStats({required this.truths, required this.dares, required this.passes, this.topTaker, this.topGiver});
  final int truths, dares, passes;
  final ({int seat, int count})? topTaker;   // over all rounds
  final ({int seat, int count})? topGiver;   // over truth + dare rounds only ("asked most")
  factory GameStats.of(List<RoundEntry> rounds);   // ties → lowest seat; null when no qualifying round
}
```

### `lib/features/session/domain/rules/labels.dart` — add
```dart
/// Seat that may no longer exist after Edit Players → unnamed player.
Player playerAt(List<Player> players, int seat) =>
    seat < players.length ? players[seat] : Player(seat: seat);

/// "P3" or "Kabir · P2" (round log, Home "last:" line).
String shortLabel(Player p) => p.name == null ? 'P${p.seat + 1}' : '${p.name} · P${p.seat + 1}';
```

### `lib/features/history/domain/rules/history_labels.dart` — new, pure
All take `DateTime` values already in local time; `now` is always a parameter.
```dart
String durationLabel(int ms);                        // "under 1 min" | "47 min" | "1 h 05 min"
String timeLabel(DateTime t, {required bool h24});   // "9:41 PM" | "21:41"
String dayLabel(DateTime t, DateTime now);           // same day: hour >= 18 ? "Tonight" : "Today"; else "Sat 21 Nov" (+ " 2025" if another year)
String groupLabel(DateTime t, DateTime now);         // "TODAY" | "THIS WEEK" (previous 6 calendar days) | "OCTOBER" (+ " 2025" if another year)
String circleLabel(List<Player> players);            // no names: "Players 1–N"; else first 3 names in seat order joined ", " + " +K" for the K players not shown
String roundsLabel(int n);                           // "1 round" | "N rounds"
String resultLabel(RoundResult r);                   // "Truth" | "Dare" | "Passed · no penalty"
```
Weekday and month names are two `const` lists in this file.

### `lib/features/history/domain/history_repository.dart` — new
Interface exactly as §6.5.

### `lib/features/session/domain/session_repository.dart` — change
Signatures exactly as §6.5; update the doc comments.

### Tests for this step
- `test/labels_test.dart`: `playerAt`, `shortLabel`.
- `test/history_labels_test.dart` (new): each function at its boundaries (59/60 min, midnight, 6 vs 7 days ago, year change, 0/1/3/4 named players, 60 players); `GameStats.of` for empty, all-pass, ties.
- `test/session_bloc_test.dart` helper `stored(...)` keeps working (log defaults to empty). Add `Session` unit cases: `chose` then `passed` leaves one entry with `pass`; `isValid` rejects a log entry with `round > session.round`.

---

## 3. Data and DI

### `lib/features/session/data/session_db.dart`
- `const int sessionDbVersion = 2;`
- Keep `sessionSchema` (v1) untouched. Add `const List<String> historySchema = [...]` with the four `CREATE TABLE` statements of §6.4, verbatim.
- `onCreate`: run `sessionSchema` then `historySchema`.
- `onUpgrade: (db, from, _) async { if (from < 2) { for (final sql in historySchema) { await db.execute(sql); } } }`.
- `onOpen: (db) => db.delete('game', where: 'deleted_at IS NOT NULL')` (runs after create/upgrade; foreign keys are already on, so children cascade).
- Replace the "No onUpgrade yet" comment. `onDowngrade` and the delete-and-reopen catch stay as they are.

### `lib/features/session/data/session_repository_impl.dart`
- `load()`: after the players query, `final log = await _db.query('round_log', orderBy: 'round');` and build `Session(..., log: [for (final r in log) RoundEntry(round:, taker:, giver:, result: RoundResult.values.byName(r['result']! as String))])` inside the existing `try`, so a bad row follows the existing corrupt path.
- Private helper, used by `start` and `end`:
```dart
/// Copies the stored session into game/game_player/game_round when it has at
/// least one logged round. Does not delete it. Returns whether it archived.
Future<bool> _archive(Transaction txn, int endedAtMs) async {
  final n = Sqflite.firstIntValue(await txn.rawQuery('SELECT COUNT(*) FROM round_log')) ?? 0;
  if (n == 0) return false;
  await txn.rawInsert(
    'INSERT INTO game (id, started_at, ended_at, player_count) '
    'SELECT id, started_at, MAX(?, started_at), player_count FROM session', [endedAtMs]);
  await txn.rawInsert('INSERT INTO game_player (game_id, seat, name) SELECT session_id, seat, name FROM player');
  await txn.rawInsert(
    'INSERT INTO game_round (game_id, round, taker, giver, result) '
    'SELECT session_id, round, taker, giver, result FROM round_log');
  return true;
}
```
- `start(players)`: inside the existing transaction, call `await _archive(txn, nowMs)` immediately before the existing `txn.delete('session')`.
- `saveRound(Session s, {RoundEntry? log})`: when `log == null`, unchanged. Otherwise one `_db.transaction`: the same `UPDATE` (still `throw const StorageFailure()` when `n != 1`, which rolls back), then `txn.insert('round_log', {...'session_id': s.id}, conflictAlgorithm: ConflictAlgorithm.replace)`.
- `end(Session s)`:
```dart
final endedAt = max(DateTime.now().toUtc().millisecondsSinceEpoch, s.startedAtMs);
final archived = await _db.transaction((txn) async {
  final a = await _archive(txn, endedAt);
  await txn.delete('session');
  return a;
});
return archived
    ? GameRecord(id: s.id, startedAtMs: s.startedAtMs, endedAtMs: endedAt, players: s.players, rounds: s.log)
    : null;
```
All inside `_guard`.

### `lib/features/history/data/history_repository_impl.dart` — new
`@LazySingleton(as: HistoryRepository)`, constructor `(Database)`, same `_guard` pattern (copy the 7 lines; do not share a base class).
- `games()`: three queries — `game` (`where: 'deleted_at IS NULL'`, `orderBy: 'ended_at DESC'`), `game_player` (`orderBy: 'game_id, seat'`), `game_round` (`orderBy: 'game_id, round'`) — grouped by id in Dart. Add the comment: `// ponytail: loads the whole history; page it if it ever exceeds a few hundred games.`
- `softDelete(ids, atMs)` / `restore(ids)`: no-op on an empty list; one `rawUpdate` with `WHERE id IN (${List.filled(ids.length, '?').join(',')})`.
- `purgeDeleted()`: `_db.delete('game', where: 'deleted_at IS NOT NULL')`.

### DI
No change to `injection.dart`; run `fvm dart run build_runner build --delete-conflicting-outputs` after step 4 and commit `injection.config.dart`.

### Tests
`test/session_repository_test.dart` — extend:
- "schema, pragmas": the four new tables exist; `PRAGMA user_version` is 2.
- **Migration:** create a temp file (`Directory.systemTemp.createTemp`), open it with `databaseFactoryFfi` at `version: 1` running `sessionSchema` only, insert one session + players, close; `openSessionDb(factory: databaseFactoryFfi, path: file)`; assert session and players unchanged, new tables present, version 2. Delete the temp dir in `addTearDown`.
- `saveRound` with `log`: row present; second call for the same round replaces it; with an unknown session id nothing is written to `round_log`.
- `end`: with rounds → `game`, `game_player`, `game_round` filled, `session`/`player`/`round_log` empty, returned record equals what `HistoryRepositoryImpl.games()` returns; without rounds → null and `game` empty.
- `start` over a stored session with rounds archives it; without rounds leaves `game` empty.
- CHECKs: `result = 'x'`, `taker = giver`, `ended_at < started_at` refused.
- Reopen purge: use a temp file, soft-delete, close, reopen → row gone, children gone.

`test/history_repository_test.dart` (new): order newest first; players and rounds attached to the right game; `softDelete` hides; `restore` shows; `purgeDeleted` removes only soft-deleted rows and cascades.

---

## 4. Bloc and cubit

### `session_state.dart`
```dart
final class SessionSummary extends SessionState {
  const SessionSummary(this.game);
  final GameRecord game;
  // == on game; hashCode Object.hash(SessionSummary, game)
}
```
### `session_event.dart`
`final class SummaryDismissed extends SessionEvent { const SummaryDismissed(); }`

### `session_bloc.dart`
- Dispatch: add `SummaryDismissed() => _dismissSummary(emit)`. `Passed` uses `a.session.passed()`.
- `_persist` gains `{bool log = false}`; when true it calls `_repo.saveRound(next, log: next.log.last)`. Pass `log: true` for `ModeChosen` and `Passed`, not for `NextRoundRequested`.
- `_start`: accept `NoSession`, `ResumePrompt` and `SessionSummary` (`final s = state;` guard). On `Failure f`: `ResumePrompt` → `emit(ResumePrompt(s.session, failure: f))`; otherwise `emit(NoSession(notice: f.message))`.
- `_end`: accept only `SessionActive` that is not spinning. `final game = await _repo.end(s.session); emit(game == null ? const NoSession() : SessionSummary(game));` Failure → `_with(s, s.session, failure: f)`.
- `_dismissSummary`: `if (state is SessionSummary) emit(const NoSession());`
- `_spin`, `_finishSpin`, `_resume`, `_editPlayers`, `_replay`: unchanged. `SpinRequested` must stay field-less.

### `lib/features/history/presentation/cubit/history_cubit.dart` — new, `@lazySingleton`
```dart
final class HistoryState {
  const HistoryState({this.loaded = false, this.games = const [], this.pending = const [], this.failure});
  final bool loaded;
  final List<GameRecord> games;      // visible, newest first
  final List<GameRecord> pending;    // soft-deleted, still undoable
  final Failure? failure;
  // == with listEquals on both lists
}

class HistoryCubit extends Cubit<HistoryState> {
  HistoryCubit(this._repo) : super(const HistoryState());
  static const undoWindow = Duration(seconds: 5);
  Future<void> load();
  Future<void> delete(List<String> ids);   // one game, or every id for Clear all
  Future<void> undo();
  Future<void> purgeNow();                 // also the Phase 3 background hook
}
```
Behaviour:
- `load()`: `emit(loaded: true, games: await _repo.games(), pending: state.pending)`; on `Failure` keep the lists, set `failure`.
- `delete(ids)`: compute `removed` = visible games with those ids; return if empty. **Emit `games − removed`, `pending: removed` before the first `await`** (a `Dismissible` must leave the tree in the next frame). Cancel the timer. Then `if (hadPending) await _repo.purgeDeleted();` → `await _repo.softDelete(ids, nowMs);` → start `Timer(undoWindow, purgeNow)`. On `Failure`: `emit` the result of `_repo.games()` if that succeeds (else the previous `games`), `pending: const []`, `failure`.
- `undo()`: return if `pending` is empty; cancel the timer; `await _repo.restore(ids)`; then `load()` with `pending: const []`. On `Failure`: keep `pending`, set `failure`, restart the timer.
- `purgeNow()`: cancel the timer; if `pending` is empty return; `try { await _repo.purgeDeleted(); } on Failure { /* purged at next open */ }`; `emit(pending: const [])`.
- `close()`: cancel the timer, then `super.close()`.
- No `BuildContext`, no navigation.

### Tests
`test/support/fake_session_repository.dart`: new signatures; optional `FakeHistoryRepository? history`; `end` builds the record from the session (null when `session.log` is empty) and adds it to `history`; `start` archives the previous `stored` the same way.
`test/support/fake_history_repository.dart` (new): in-memory `games` and a `deleted` id set, `failWrites`, `calls`.
`test/session_bloc_test.dart`: every row of §6.2. Keep the existing double-spin and failure tests. Replace the "End from ResumePrompt" cases with "EndConfirmed is ignored in ResumePrompt".
`test/history_cubit_test.dart` (new): P2b-7, using `fakeAsync` for the 5 s window. The "emits before first await" test reads `cubit.state` synchronously after calling `delete` without awaiting.

---

## 5. Router, navigator, app, main

### `lib/app/router.dart`
`sessionRedirect`:
```dart
final history = path == '/history' || path.startsWith('/history/');
final setup = path == '/new' || path == '/names';
return switch (state) {
  SessionLoading() => null,
  NoSession() || ResumePrompt() => path == '/' || setup || history ? null : '/',
  SessionSummary() => path == '/summary' || history ? null : '/summary',
  SessionActive() =>
    path == '/game' || path == '/game/settings' || path == '/game/log' || path == '/game/end'
        ? null
        : (setup && edit && state.session.phase == Phase.ready && !state.spinning ? null : '/game'),
};
```
`_overlay` gains `required void Function(AppNavigator) dismiss`; the barrier `onTap` becomes `() => dismiss(ctx.read<AppNavigator>())`. Existing overlays pass `(n) => n.game()`.

Route tree (`initialLocation: '/'`):
```
/                      HomePage
  new                  NewGamePage(editing)
  names                AddNamesPage(editing)
  history              HistoryPage
    clear              _overlay(DeleteConfirmPage(id: null), dismiss: history)        // declare before :id
    :id                HistoryDetailPage(id)
      delete           _overlay(DeleteConfirmPage(id: id), dismiss: historyDetail(id))
/summary               SummaryPage
/game                  GamePage
  settings             _overlay(SettingsSheetPage, dismiss: game)
  log                  _overlay(RoundLogSheetPage, dismiss: game)
  end                  _overlay(EndConfirmPage, dismiss: game)
```
Confirm overlays use the existing `Color(0x8C040810)` barrier; sheets use `Tokens.scrim`. Remove the `/resume` route and the `resume_page.dart` import. Delete `lib/features/session/presentation/pages/resume_page.dart`.

### `lib/app/app_navigator.dart` — add
```dart
void home() => _router.go('/');
void history() => _router.go('/history');
void historyDetail(String id) => _router.go('/history/$id');
void confirmDelete(String id) => _router.go('/history/$id/delete');
void confirmClear() => _router.go('/history/clear');
void roundLog() => _router.go('/game/log');
```

### `lib/app/app.dart`
- Add `BlocProvider<HistoryCubit>.value(value: getIt<HistoryCubit>())`.
- Replace the single `BlocListener` with a `MultiBlocListener`:
  1. `listenWhen: (a, b) => a is SessionActive && (b is NoSession || b is SessionSummary)` → `context.read<SetupCubit>().reset()`.
  2. `listenWhen: (a, b) => a.runtimeType != b.runtimeType` → `context.read<HistoryCubit>().load()`.

### `lib/main.dart`
After the `SessionLoading` wait and before `runApp`: `unawaited(getIt<HistoryCubit>().load());`

### `test/router_redirect_test.dart`
Rewrite the path list to every path in §6.3 plus `/resume` (now unknown) and `/history/abc`, `/history/abc/delete`. One test per state. Add the property test: for every state and path, if `r(s, p)` is non-null then `r(s, r(s, p)!)` is null.

---

## 6. Platform and rules

### `lib/platform/glass_button.dart` — new (the only file importing the package)
```dart
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart'
    show IOS26Button, IOS26ButtonStyle, SFSymbol;

/// Small native glass chrome button (pill, icon button, sheet Done, Undo).
/// Liquid Glass on iOS 26+, system material on iOS 17–25 (IOS26Button's own
/// native fallback). Flat surface off iOS and while [flat].
class GlassButton extends StatelessWidget {
  const GlassButton({
    required this.label,        // VoiceOver label, always required
    required this.onPressed,
    required this.child,        // Flutter-drawn content; gives the width
    this.symbol,                // SF Symbol name; when set, [child] is only the flat-path glyph
    this.height = Tokens.touch,
    this.prominent = false,     // white capsule; caller draws navy content
    this.flat = false,          // true while another route covers the page
    super.key,
  });
}
```
Build:
- Outer: `Semantics(button: true, label: label, onTap: onPressed, excludeSemantics: true, child: …)`.
- Native path (`defaultTargetPlatform == TargetPlatform.iOS && !flat`):
  - `symbol != null`: `SizedBox.square(dimension: height, child: IOS26Button.sfSymbol(onPressed: onPressed, sfSymbol: SFSymbol(symbol!, size: 18, color: Tokens.textPrimary), style: IOS26ButtonStyle.glass, useSmoothRectangleBorder: false))`.
  - otherwise: `SizedBox(height: height, child: Stack(children: [Positioned.fill(child: IOS26Button(onPressed: onPressed, label: '', style: prominent ? IOS26ButtonStyle.prominentGlass : IOS26ButtonStyle.glass, color: prominent ? const Color(0xFFFFFFFF) : null, useSmoothRectangleBorder: false)), IgnorePointer(child: Padding(padding: const EdgeInsets.symmetric(horizontal: Tokens.s16), child: Center(widthFactor: 1, child: child)))]))`.
- Flat path: `GestureDetector(behavior: HitTestBehavior.opaque, onTap: onPressed, child: Container(height: height, width: symbol != null ? height : null, padding: symbol != null ? null : const EdgeInsets.symmetric(horizontal: Tokens.s16), decoration: ShapeDecoration(color: prominent ? const Color(0xEBFFFFFF) : Tokens.bgRaised, shape: const StadiumBorder(side: BorderSide(color: Tokens.line))), child: Center(widthFactor: 1, child: child)))`.
- Do not use `AdaptiveButton`, the package's `.child` constructor, or any other package symbol (D2, D3).

### `lib/platform/native_action_bar.dart`
`enum ActionBarStyle { primary, secondary, destructive, choice, prominent, chip, chipOn }`. Nothing else changes.

### `ios/Runner/Native/ActionBarView.swift`
- `known` gains `"prominent", "chip", "chipOn"`.
- Add `private let navy = Color(red: 0x0B / 255, green: 0x14 / 255, blue: 0x24 / 255)`.
- In `button(_:)`:
  - `let fills = ["prominent", "chip", "chipOn"].contains(item.style)` — v2 styles fill the rect Flutter gives; v1 styles keep their minimum heights.
  - `let light = item.style == "prominent" || item.style == "chipOn"` — white capsule, navy label.
  - Label frame: `.frame(maxWidth: .infinity, minHeight: item.style == "primary" ? 64 : (fills ? 44 : 50), maxHeight: fills ? .infinity : nil)`; chips add `.fontWeight(.heavy)`.
  - Foreground: `destructive` coral, `light` navy, else white.
  - iOS 26: `primary` as today; `light` → `.buttonStyle(.glassProminent).tint(.white.opacity(0.92))`; else `.glass`.
  - Below 26: `light` → `.background(Color.white.opacity(0.92), in: Capsule())`; else `.ultraThinMaterial` as today.
  - Chips: `.accessibilityLabel("\(item.label) players")` and `.accessibilityAddTraits(item.style == "chipOn" ? .isSelected : [])`.
- No haptics in Swift.

### `ios/Runner/Native/PickerView.swift`
- Row text becomes the bare number: `Text("\($0)").tag($0)` (the wheel now shares its row with the seat preview; the picker's own label "Number of players" stays).
- In `PickerModel.apply`, the final assignment becomes `if newValue != value { withAnimation { value = newValue } }` (chip tap animates the wheel).

### `tool/check_rules.sh` — add
```sh
src -l "package:adaptive_platform_ui" lib/ | grep -v '^lib/platform/' \
  && bad 'adaptive_platform_ui may only be imported under lib/platform/'
src 'Adaptive(App|Scaffold|AlertDialog|SnackBar|BlurView|Button|PopupMenuButton|ContextMenu|Card)\b|Ios26NativeBlurView|IOS26AlertDialog' lib/ \
  && bad 'only IOS26Button (and, from Phase 3, AdaptiveSwitch/AdaptiveSlider) may be used from adaptive_platform_ui'
```
The existing bans and the `StatefulWidget` allowlist do not change.

---

## 7. Tokens and shared UI

### `lib/app/tokens.dart` — add
`barProminent = 60`, `barHub = 54`, `chip = 44`, `flickMinSpeed = 3.0` (rad/s), `snapBack = Duration(milliseconds: 180)`, `rowCollapse = Duration(milliseconds: 250)`. Text on prominent (white) buttons uses the existing `Tokens.bgBase` (`0xFF0B1424`); do not add a second navy token.

### `lib/app/ui.dart` — add four widgets
1. **`TopRoute`** — the Phase 2 "covered" logic, moved out of `GamePage`:
```dart
class TopRoute extends StatelessWidget {
  const TopRoute({required this.path, required this.builder, super.key});
  final String path;
  final Widget Function(BuildContext context, bool covered) builder;
  // ListenableBuilder on GoRouter.of(context).routerDelegate;
  // covered = routerDelegate.currentConfiguration.uri.path != path
}
```
Every page with native views wraps its body in it. Covered → action bars become same-height `SizedBox`es, `GlassButton(flat: true)`.

2. **`SheetFrame`** — shared by Round log and Session sheets (D14):
```dart
class SheetFrame extends StatelessWidget {
  const SheetFrame({required this.title, this.subtitle, required this.onDone, required this.slivers, super.key});
}
```
`Align(bottomCenter)` → `ConstrainedBox(maxWidth: Tokens.maxContentWidth)` → `NotificationListener<DraggableScrollableNotification>(onNotification: (n) { if (n.extent <= n.minExtent + 0.01) onDone(); return false; })` → `DraggableScrollableSheet(expand: false, initialChildSize: 0.55, minChildSize: 0.25, maxChildSize: 0.93, snap: true, snapSizes: const [0.55], builder: (context, controller) => Material(color: Tokens.bgSheet, shape: top radius 34 + line border, clipBehavior: Clip.antiAlias, child: SafeArea(top: false, child: CustomScrollView(controller: controller, slivers: [PinnedHeaderSliver(child: header), ...slivers]))))`.
Header (background `Tokens.bgSheet`, padding 16/10/16/8): grabber 40×5; row with title (`Tokens.title2`), optional subtitle (14, `textSecondary`), and `GlassButton(label: 'Done', height: 36, onPressed: onDone, child: Text('Done', 15 semibold))`. Text beside the button uses `besideIsland`.

3. **`ConfirmSheet`** — the layout of today's `EndConfirmPage` with parameters `title`, `body`, `confirmLabel`, `onConfirm`, `onCancel`, `Failure? failure`. Bar item ids are `'confirm'` (style `destructive`) and `'cancel'` for every confirm sheet; the Phase 2 id `'end'` is retired, so update the tests that tap it. `EndConfirmPage` and `DeleteConfirmPage` both build it.

4. **`TextLink`** — teal 17-pt tappable text with a 44-pt minimum hit box and `Semantics(button: true)`; optional leading `Icons.chevron_left`. Used for "‹ Home", "‹ History", "See all", "View round log", coral variant for "Clear all" / "Delete game" via a `color` parameter.

### `lib/features/game/presentation/widgets/dial_preview.dart` — new
```dart
/// Static dial: seat preview (New game) and mini dial (Home card).
class DialPreview extends StatelessWidget {
  const DialPreview({required this.n, this.orientation = 0, super.key});
}
```
`FittedBox(child: SizedBox.square(dimension: 240, child: CustomPaint(painter: DialPainter(n: n, spin: kAlwaysDismissedAnimation, pulse: kAlwaysDismissedAnimation, orientation: orientation))))`, wrapped in `ExcludeSemantics`. No new painter.

---

## 8. Pages

Common: `Scaffold(backgroundColor: Tokens.bgBase)`, `PageFrame`, `barScale(context)` for island heights, `besideIsland(context)` for text sharing a row with an island. Sentence case as on the v2 artboards ("New game", "Start session", "Add names", "Resume game").

### 8.1 `lib/features/home/presentation/pages/home_page.dart` — new · artboard `Home`
- `BlocBuilder<SessionBloc>`; states other than `NoSession` / `ResumePrompt` → empty scaffold. Inside, `TopRoute(path: '/')`.
- One `SingleChildScrollView` (horizontal padding 16–20 as on the artboard):
  1. Header row: `LogoMark`, "Spinfolk" (`Tokens.numeral(26)`), spacer, `GlassButton(label: 'History', symbol: 'clock.arrow.circlepath', onPressed: nav.history, child: Icon(Icons.history, color: Tokens.textPrimary, size: 22))`.
  2. `NoticeBanner` for `NoSession.notice` or `ResumePrompt.failure`.
  3. `ResumePrompt` only — card (`bgSurface`, `line`, radius 28, padding 18): row of `SizedBox.square(64, DialPreview(n, orientation: outcome == null ? 0 : seatAngle(taker, n)))` and a column: caption `IN PROGRESS · ${durationLabel(now − startedAt).toUpperCase()}` in `taker`; `title2` `Round R`; subhead `N players · last: {giver} → {taker} · Truth` built from `session.log.last` with `shortLabel(playerAt(...))` (`· Dare`, or `last: passed`; `N players · no rounds yet` when the log is empty). Then `NativeActionBar([resume: 'Resume game', prominent])`, height `Tokens.barHub * sc` → `ResumeConfirmed`.
  4. `NativeActionBar([new: 'New game', ResumePrompt ? secondary : prominent])`, height `Tokens.barHub * sc` → `nav.setup()`.
  5. `ResumePrompt` only — footnote "Starting a new game ends and saves the current one."
  6. When `HistoryState.games` is not empty: "Recent" (`title2`) + `TextLink('See all', nav.history)`, then a card with the first 3 `GameRow`s (no swipe).
- `DateTime.now()` and `MediaQuery.alwaysUse24HourFormatOf(context)` are read in `build` and passed to the label functions.

### 8.2 `new_game_page.dart` — rewrite body · artboard `NewGame2`
- `TopRoute(path: '/new')`.
- Top: `editing` → existing "Cancel"; else `TextLink('Home', leading chevron, nav.home)`. Remove the logo row.
- Title `editing ? 'Edit Players' : 'New game'`; "How many in the circle?".
- Notice: `NoSession.notice` or `ResumePrompt.failure?.message`.
- Chips: `SizedBox(height: Tokens.chip * sc, child: BlocBuilder<SetupCubit>(buildWhen: count, builder: NativeActionBar(layout: row, items: [for (final n in const [4, 6, 8, 10, 12]) ActionBarItem(id: 'count:$n', label: '$n', style: st.count == n ? chipOn : chip)], onTap: (id) { HapticFeedback.selectionClick(); cubit.countChanged(int.parse(id.substring(6))); })))`.
- `LayoutBuilder` row, height `Tokens.pickerHeight`: `Expanded(NativePicker(...))`, gap 12, preview card of width `min(170, (maxWidth − 12) / 2)` (`bgSurface`, `line`, radius 24, padding 10): `Expanded(DialPreview(n: st.count))` + caption "Live seat preview" (13, `textTertiary`, `besideIsland`, max 2 lines), with `Semantics(image: true, label: 'Seating preview for ${st.count} players')`.
- Text "Sit in number order, clockwise. Player 1 sits where the bottle’s neck points now."
- Names row card (radius 18): "Add names" / "Optional · numbers work fine" / `›`; with names: "Edit names" / "N named". Same `onTap` as today.
- Bottom bar: `[start: 'Start session' | save: 'Save Players']`, style `prominent`, height `Tokens.barProminent * sc`. Remove the old footnote and the old seating card.

### 8.3 `game_page.dart` · artboard `Ready2`
- Replace the inline `ListenableBuilder` with `TopRoute(path: '/game')`.
- `_Pill` → `GlassButton(label: 'Round $round · $n players', flat: covered, onPressed: nav.roundLog, child: Row(mainAxisSize: min, [existing Text.rich, 6 gap, '›']))`, still inside `Flexible`.
- `_SettingsButton` → `GlassButton(label: 'Session and settings', symbol: 'ellipsis', flat: covered, onPressed: nav.settings, child: <the existing three dots>)`.
- Ready panel (`phase == ready && !spinning`): text "Flick the bottle, or tap Spin." (15, `textSecondary`, centred), then — when `session.log` is not empty — the "LAST" card (`bgSurface`, `line`, radius 16): `LAST` caption, `{giver} → {taker} · Truth` in coral/teal (or "Passed · no penalty"), trailing "Round log ›"; whole card taps `nav.roundLog`, `Semantics(button: true, label: 'Round log')`. When the log is empty keep the existing legend card.
- Everything else (bars, other panels, sizing fractions) unchanged.

### 8.4 Flick — `lib/features/game/presentation/widgets/flick.dart` (new, pure) + `spin_stage.dart` + `dial_painter.dart`
`flick.dart`:
```dart
/// Signed angle from [a] to [b] around the origin, clockwise positive (y down).
double angleDelta(Offset a, Offset b) => atan2(a.dx * b.dy - a.dy * b.dx, a.dx * b.dx + a.dy * b.dy);
/// Angular speed in rad/s of a point at [r] from the centre moving at [v] px/s. 0 inside 8 px.
double angularVelocity(Offset r, Offset v) => r.distanceSquared < 64 ? 0 : (r.dx * v.dy - r.dy * v.dx) / r.distanceSquared;
/// Wraps to (-pi, pi].
double wrapPi(double a);
```
`dial_painter.dart`: new optional `Animation<double> drag = kAlwaysDismissedAnimation`, merged into `repaint`. Bottle angle: resting `orientation + drag.value`; spinning `start + (p.end − start) * curve(spin.value)` with `start = p.start + drag.value`; Reduce Motion fades out the bottle at `start`. Nothing else in the painter changes; `plan.end` is never modified.

`spin_stage.dart` (still the only `StatefulWidget`, still no `setState`):
- `late final AnimationController _drag = AnimationController.unbounded(vsync: this);` disposed with the others; passed to the painter.
- `Offset? _grab;` (pointer vector from the centre while a drag is active).
- Wrap the `CustomPaint` in `GestureDetector`; handlers are non-null only when `!s.spinning && s.session.phase == Phase.ready`:
  - `onPanStart`: `v = localPosition − size.center` with `size = context.size!`; ignore unless `8 < v.distance <= size.shortestSide / 2 * 0.66` (the bottle's sweep); else `_grab = v; _drag.stop(); HapticFeedback.lightImpact();`
  - `onPanUpdate`: if `_grab != null`: `_drag.value += angleDelta(_grab!, v); _grab = v;`
  - `onPanEnd`: if `_grab != null`: `w = angularVelocity(_grab!, details.velocity.pixelsPerSecond); _grab = null;` then `w.abs() >= Tokens.flickMinSpeed` → `_drag.value = wrapPi(_drag.value); bloc.add(const SpinRequested());` else `_drag.animateTo(0, duration: Tokens.snapBack, curve: Curves.easeOut)`.
  - `onPanCancel`: `_grab = null; _drag.animateTo(0, …)`.
- In the existing listener's "spin ended" branch add `_drag.value = 0;` (covers reveal and a failed save).
- Semantics: add `hint: 'Flick to spin, or use the Spin button'` when the handlers are active. The Spin button remains the accessible path.
- Never read `_drag` or the velocity into an event (D11).

### 8.5 `lib/features/game/presentation/pages/round_log_sheet_page.dart` — new · artboard `RoundLog`
`BlocBuilder<SessionBloc>`; non-`SessionActive` → `SizedBox.shrink()`. `SheetFrame(title: 'Round log', subtitle: '${roundsLabel(n)} · $t Truth · $d Dare · $p pass', onDone: nav.game, slivers: [SliverToBoxAdapter(RoundLogList(players: session.players, rounds: session.log))])`. Empty log → centred "No rounds yet. Spin to start." Opens in every game state, including while spinning.

### 8.6 `settings_sheet_page.dart`
Keep the private `_Label`, `_Card`, `_Row`, `_Divider` widgets (Phase 3 reuses them). Replace the `Align`/`ConstrainedBox`/`Material`/grabber/title row with `SheetFrame(title: 'Session', onDone: nav.game, slivers: [SliverToBoxAdapter(Padding(16, Column(<existing PLAYERS and SESSION sections unchanged>)))])`. Row behaviour and copy unchanged.

### 8.7 `end_confirm_page.dart`
Build `ConfirmSheet`. Only `SessionActive` is handled now (drop the `ResumePrompt` branch). Body: `'Saves $n players and $r ${r == 1 ? 'round' : 'rounds'} to History. Voice settings stay. Lock Screen activity ends too.'` where `r = session.log.length`; when `r == 0`: `'No rounds played, so nothing is saved. Voice settings stay. Lock Screen activity ends too.'` Confirm label "End Session".

### 8.8 History widgets — `lib/features/history/presentation/widgets/`
- `game_row.dart` — `GameRow({required GameRecord game, required DateTime now, required bool h24, required VoidCallback onTap})`: three lines per the artboard (`'${dayLabel} · ${timeLabel}'` from `endedAtMs`; `'N players · ${roundsLabel} · ${durationLabel}'`; `circleLabel`, one line, ellipsis) + `›`. Minimum height 44. `MergeSemantics` + `button: true`.
- `round_log_list.dart` — `RoundLogList({required List<Player> players, required List<RoundEntry> rounds})`: card (radius 22), newest first; row = round number (`Tokens.numeral(15)`, `textTertiary`, width 28), then `{giver} → {taker}` with `shortLabel(playerAt(...))` in coral/teal + a result chip (`bgRaised` capsule), or "Passed · no penalty" in `textTertiary`. A plain `Column` (the parent scrolls).
- `stat_tiles.dart` — `StatTiles(GameStats)`: three equal tiles "Truths / Dares / Passes" (number `Tokens.numeral(28)`).
- `undo_toast.dart` — `UndoToast({required int count, required VoidCallback onUndo, required bool flat})`: capsule, height 60, `bgRaised` + `line`; `TweenAnimationBuilder<double>(key: ValueKey(...), tween: Tween(begin: 1, end: 0), duration: HistoryCubit.undoWindow)` drawing a 22-px `CircularProgressIndicator(value: v, strokeWidth: 2.5, color: Tokens.textPrimary)` (a static full ring when `MediaQuery.disableAnimationsOf`); text `count == 1 ? 'Game deleted' : '$count games deleted'`; `GlassButton(label: 'Undo', prominent: true, flat: flat, onPressed: onUndo, child: Text('Undo', 16 bold, Tokens.bgBase))`. Wrap in `Semantics(liveRegion: true, container: true)`.

### 8.9 `lib/features/history/presentation/pages/history_page.dart` — new · artboards `History`, `HistorySwipe`, `HistoryUndo`, `HistoryEmpty`
- `TopRoute(path: '/history')`, `BlocBuilder<HistoryCubit>`.
- Header: `TextLink('Home', chevron, nav.home)`; trailing coral `TextLink('Clear all', nav.confirmClear)` only when `games` is not empty. Title "History". `NoticeBanner` for `failure`.
- Not loaded → empty. Loaded and `games.isEmpty && pending.isEmpty` → empty state: `LogoMark(size: 72)`, "No past games yet", the artboard paragraph, bottom `NativeActionBar([start: 'Start a game', secondary])` → `nav.setup()`.
- Otherwise a scroll view (bottom padding 84): games bucketed by `groupLabel` in list order; per bucket a 13-pt header and one clipped card (radius 22) of rows separated by 1-px `line` dividers (the divider is inside the row's child so it collapses with it). Each row:
```dart
Dismissible(
  key: ValueKey(game.id),
  direction: DismissDirection.endToStart,
  dismissThresholds: const {DismissDirection.endToStart: 0.6},
  resizeDuration: Tokens.rowCollapse,
  background: <coral Tokens.giver, right-aligned 96-pt column: Icons.delete_outline + 'Delete' 14 bold, Tokens.bgBase>,
  onUpdate: (d) { if (d.reached && !d.previousReached) HapticFeedback.heavyImpact(); },
  onDismissed: (_) => cubit.delete([game.id]),
  child: Semantics(
    customSemanticsActions: {const CustomSemanticsAction(label: 'Delete game'): () => cubit.delete([game.id])},
    child: GameRow(..., onTap: () => nav.historyDetail(game.id)),
  ),
)
```
- Footnote "Stored only on this iPhone. Swipe left on a game to delete it."
- Toast: `Stack` → `Positioned(left: 16, right: 16, bottom: 8)` inside the `SafeArea`, `AnimatedSwitcher` (200 ms; zero with Reduce Motion) showing `UndoToast` while `pending` is not empty; key it by `pending.first.id` + length so the ring restarts.

### 8.10 `history_detail_page.dart` — new · artboard `HistoryDetail`
- `HistoryDetailPage({required String id})`; `TopRoute(path: '/history/$id')`; find the record in `HistoryState.games`.
- Not found once loaded → `TextLink('History', chevron, nav.history)` + "This game is no longer in History."
- Scroll area: back link; title `dayLabel` (large title); `'${timeLabel} · N players · ${roundsLabel} · ${durationLabel}'`; `StatTiles`; `Wrap` of player chips (`shortLabel`, `bgRaised` capsule, 14 pt); "ROUND LOG" header; `RoundLogList`.
- Bottom, outside the scroll: `NativeActionBar([again: 'Play again with this circle', prominent])`, height `Tokens.barProminent * sc` → `SessionStarted(game.playerCount, [for (final p in game.players) p.name])`; footnote "Starting a new game ends and saves the current one." only when the session state is `ResumePrompt`; coral `TextLink('Delete game', () => nav.confirmDelete(id))`.

### 8.11 `delete_confirm_page.dart` — new · artboard `DeleteConfirm`
`DeleteConfirmPage({required String? id})` builds `ConfirmSheet`:
- One game: title "Delete this game?"; body `'${dayLabel} · N players · ${roundsLabel}. Its names and round log are removed from this iPhone. You can undo for a few seconds.'`; confirm "Delete game" → `cubit.delete([id]); nav.history();`; cancel → `nav.historyDetail(id)`.
- Clear all (`id == null`): title "Clear all history?"; body `'N games and their round logs are removed from this iPhone. You can undo for a few seconds.'`; confirm "Clear all" → `cubit.delete([for (final g in state.games) g.id]); nav.history();`; cancel → `nav.history()`.
- Record missing → `SizedBox.shrink()`.

### 8.12 `summary_page.dart` — new, in `lib/features/history/presentation/pages/` · artboard `EndSummary`
- `BlocBuilder<SessionBloc>`; non-`SessionSummary` → empty scaffold. `TopRoute(path: '/summary')`.
- Scroll area: `LogoMark`; "Good game."; `'${durationLabel} · ${roundsLabel} · N players'`; `StatTiles`; ratio bar (height 10, capsule, three `Expanded(flex: count)` segments in `0xFFE8EEF7`, `0xFF7C8BA5`, `Tokens.line`, zero-count segments omitted, `Semantics(image: true, label: '7 truths, 4 dares, 1 pass')`); card with "Taker most often" → `'${displayLabel(playerAt(...))} · K×'` in `taker` and "Asked most" → same in `giver` (each row only when its stat is non-null); footnote "Saved to History on this iPhone." + `TextLink('View round log', () => nav.historyDetail(game.id))`.
- Bottom: `NativeActionBar` stack `[again: 'Play again · same players' prominent, done: 'Done' secondary]`, height `(Tokens.barProminent + Tokens.barGap + Tokens.barSecondary) * sc`. `again` → `SessionStarted(...)` from the record; `done` → `SummaryDismissed`.

---

## 9. Widget tests

### `test/support/harness.dart`
- `pumpApp(..., List<GameRecord> history = const [])`: also registers `FakeHistoryRepository` (seeded), `HistoryRepository`, and `HistoryCubit` as a singleton; gives the `FakeSessionRepository` the same fake; calls `getIt<HistoryCubit>().load()` before pumping; closes the cubit in teardown.
- Add `FakeHistoryRepository historyRepo() => getIt<HistoryRepository>() as FakeHistoryRepository;`
- Add `Future<void> tapLabel(WidgetTester t, String label)` → `tester.tap(find.bySemanticsLabel(label)); pump ×2` (GlassButtons and TextLinks render their flat path on the test host).
- `tapBar` unchanged. Confirm dialogs now use ids `confirm` / `cancel`; chips use `count:N`.

### Update existing tests to v2 copy and flow
`app_smoke_test.dart`: nothing stored → Home ("Spinfolk" header, no `IN PROGRESS` text), then `tapBar('new')` → `find.text('New game')`; stored session → a text starting with `IN PROGRESS` and an enabled `resume` bar item. `game_flow_test.dart`: every loop starts with `tapBar('new')`; End → `tapBar('confirm')` → "Good game." → `tapBar('done')` → Home. Replace the two "End from Resume" tests with "Resume from Home" and "New game over an in-progress game archives it" (`historyRepo().games.length == 1`). `layout_test.dart`: replace the Resume visit with Home (both variants).

### New cases
- `test/flick_test.dart`: `angleDelta`, `angularVelocity` (sign, centre guard), `wrapPi`; widget cases with `tester.flingFrom(centre + Offset(0, -60), const Offset(120, 0), 1500)` → "Waiting for the bottle…"; `tester.dragFrom` followed by a 500 ms hold → phase still ready and bottle angle back at rest after `pumpAndSettle`; a drag that starts on the rim (outside 0.66 r) does nothing; flick during `revealed` does nothing; **same seed, flick vs `tapBar('spin')` → identical `repo.stored!.outcome`**.
- `test/game_flow_test.dart`: chip tap sets count (`tapBar('count:6')`); pill and "LAST" card open the round log with the right rows after Truth, Dare, Pass and Truth-then-Pass; summary numbers; "Play again · same players" → `Round 1` with the same names and `historyRepo().games.length == 1`; Done → Recent row visible on Home.
- `test/history_flow_test.dart` (new): empty state → "Start a game"; grouped list from seeded records; `tester.drag(row, const Offset(-400, 0))` → row gone, "Game deleted" shown, `Undo` restores; no undo → after `pump(const Duration(seconds: 6))` the fake's row is purged and the toast is gone; detail → Delete game → confirm → back on the list with the toast; Clear all → confirm → empty list, "N games deleted" → Undo restores all; detail of an unknown id shows the "no longer in History" text; Play again from detail while a session is in progress archives it.
- `test/layout_test.dart`: add Home (no session; in-progress with 40-char names in the last round), New game (count 60), Round log sheet with 60 rounds and long names, Session sheet, Summary, History list (5 records, 60 players, long names), History empty, Detail (60 players), both confirm sheets, History with the toast up. Same sizes and scales as Phase 2; `expect(tester.takeException(), isNull)` after each.

---

## 10. Maestro (deferred) and spec amendment

- Update `tool/maestro/loop.yaml`, `screens.yaml`, `edit.yaml` to v2 copy and flow (Home → "New game" → "Start session"; relaunch → "Resume game"; End → "Good game." → "Done"). Add `tool/maestro/history.yaml`: play two rounds, End, Done, open History, open the game, back, swipe the row left, assert "Game deleted", tap "Undo", assert the row, swipe again, wait 6 s, assert "No past games yet".
- First line of each flow file: `# DEFERRED (owner decision): not run in Phase 2b. Run when all phases are done.` Screenshot paths point to `docs/plans/phase-2b/evidence/`. Do not run them; do not edit `tool/phase2_gate.sh` beyond the evidence path if you touch it at all.
- Append to `docs/spec-v2.md` a section `## Amendments — Phase 2b (2026-11-22)` with: the glass rule (copy `prd.md` §6.1), the dependency (`adaptive_platform_ui 1.0.2`, removed from "deliberately not added: any glass package"), the route table (§6.3), the state list and the new event (§6.2), the v2 tables (§6.4), and the line "End Session archives to History; a game with no logged round is not saved." State that these override A1-12, A4, A6 `end()` and the Part B route list.

---

## 11. Verify

Paste the output of each:
```sh
fvm dart run build_runner build --delete-conflicting-outputs
fvm dart format --set-exit-if-changed .
fvm flutter analyze
tool/check_rules.sh
fvm flutter test
fvm flutter build ios --simulator --debug
git diff --stat e425351 -- pubspec.yaml ios/        # pubspec: one dependency line; ios: ActionBarView.swift + PickerView.swift only
grep -rn "package:adaptive_platform_ui" lib/        # exactly one hit: lib/platform/glass_button.dart
grep -rnE "extends StatefulWidget" lib/             # exactly one hit: spin_stage.dart
grep -rnE "\.push\(|Navigator\.of|getIt<" lib/features lib/platform   # no hits
grep -rn "resume_page\|ResumePage\|'/resume'" lib/ test/              # no hits in lib/; only the "unknown path" case in router_redirect_test
ls ios/Podfile 2>/dev/null                          # nothing
```
Order stays codegen → format → analyze. If `dart format` flags the generated config, run `fvm dart format .` after codegen.

Common failure causes:
- `A dismissed Dismissible widget is still part of the tree`: `HistoryCubit.delete` awaited before emitting.
- go_router redirect loop: a `sessionRedirect` cell returns a path it rejects; the property test in step 5 catches it.
- `/history/clear` opens the detail page: `clear` is declared after `:id`.
- `RenderFlex overflowed` beside the wheel at 320 pt: the preview width must come from the `LayoutBuilder`, not a fixed 170.
- Swift build error on `.frame(minHeight:maxHeight:)`: all three of `maxWidth`, `minHeight`, `maxHeight` must be in one `.frame` call.
- Test taps on a `GlassButton` do nothing: use the semantics label; the flat path is a `GestureDetector`.

**Suggested commits:** `Phase 2b: adaptive_platform_ui gate, schema v2, round log and history repositories` (after step 3) · `Phase 2b: SessionSummary, HistoryCubit, Home hub routing` (after step 5) · `Phase 2b: glass chrome, chips, flick, history screens, round log and summary` (after step 9) · `Phase 2b: deferred Maestro flows and spec amendment` (after step 10).

## 12. Report format

1. What works.
2. Each acceptance check P2b-1 … P2b-10: PASS / FAIL / NOT VERIFIED with the real command output. P2b-S1 … S5: NOT VERIFIED (deferred by owner decision) — list them so they are not lost.
3. The resolved versions from `pubspec.lock` for `adaptive_platform_ui`, `foldable`, `plugin_platform_interface`, and the plugin lines of the generated SwiftPM manifest.
4. Anything in the Phase 2 code that differed from what this file assumes.
5. Deviations from this file and from the v2 artboards beyond `prd.md` §4 and §9, each with its reason.
6. Open questions from `prd.md` §9 the owner has not answered, one line each.
7. Next step: Phase 3 seams in `prd.md` §10.
