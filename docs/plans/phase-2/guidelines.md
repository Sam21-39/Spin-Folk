# Spinfolk — Phase 2: Implementation Guidelines

Read `prd.md` (this folder), `docs/spec-v2.md`, and `docs/plans/phase-0-1/guidelines.md` §0 first. The spec's architecture is fixed. This file gives order, exact paths, names, shapes and verify commands. Decision ids (D1…) refer to `prd.md` §5.

## 0. Ground rules

- All Phase 0–1 ground rules still apply: every command through `fvm`, run from `/Users/sp/Dev/Games/Spin-Folk`; no `setState`; no `showDialog` / `showModalBottomSheet` / `SnackBar` / `ScaffoldMessenger` / `BackdropFilter`; Material import is `package:material_ui/material_ui.dart`, files needing no Material widget import `package:flutter/widgets.dart`.
- **No Swift changes. No new dependencies.** `pubspec.yaml` changes only by the `assets:` and `fonts:` blocks of step 1.
- Every widget is a `StatelessWidget` except `spin_stage.dart`. Framework widgets that are stateful internally (`TextFormField`, `AnimatedContainer`, `AnimatedSwitcher`, `BlocBuilder`) are fine.
- Blocs and cubits never see `BuildContext`, never navigate. Widget callbacks only forward intent: `bloc.add(...)`, `cubit.method(...)`, `nav.method()`.
- Navigation only through `AppNavigator`, and `AppNavigator` only calls `GoRouter.go` (D6). Never `push`, never `Navigator.of`.
- Every page must render safely for one frame in a state it does not expect (redirect is asynchronous): if the bloc state is not the one the page needs, return `const SizedBox.shrink()` (or the empty dark scaffold for `GamePage`).
- Deferred items (`prd.md` §3) are **not** created, not registered, not shown disabled. Do not add a Replay button, a Voice section, `Announcer`, `LiveActivitySync`, `NativeBridge`, `SettingsCubit`, or an `AppLifecycleListener`.
- Report honestly; paste real output; anything not run is **NOT VERIFIED** with the reason.
- Git: branch `phase-2` from the tip of `phase-0-1`. Commit only if the orchestrator or owner says so; never push.

Start condition — do this before anything else:
```sh
git switch phase-0-1 && git status --short
fvm dart run build_runner build --delete-conflicting-outputs
fvm dart format --set-exit-if-changed . && fvm flutter analyze && fvm flutter test && tool/check_rules.sh
git switch -c phase-2
```
If any of these fail, Phase 0–1 is not finished: stop and report. Then re-read the files this plan builds on, because they may differ slightly from what is quoted here: `lib/main.dart`, `lib/app/{app,router,tokens}.dart`, `lib/core/di/injection.dart`, `lib/features/setup/presentation/cubit/setup_cubit.dart`, `lib/platform/native_{island,picker,action_bar}.dart`, `tool/check_rules.sh`. If a public name differs, follow the code and say so in the report.

Shell variables used below:
```sh
SIM=2938F81B-D7F8-4DFD-81D8-968C25C04F1F     # iPhone 17 Pro, iOS 26.5 (re-check: xcrun simctl list devices available)
APP=in.appamania.spinfolk
EVID=docs/plans/phase-2/evidence
```

Step order: 1 assets → 2 domain → 3 data + DI → 4 bloc → 5 setup cubit → 6 router/navigator/app/main → 7 tokens + shared UI → 8 dial + spin stage → 9 pages → 10 cleanup + rules → 11 widget tests → 12 simulator gate. Run the static block (§12.1) after steps 2, 3, 4, 6 and 9.

---

## 1. Font and assets

```sh
mkdir -p assets/fonts
curl -fL -o assets/fonts/Nunito-wght.ttf 'https://raw.githubusercontent.com/google/fonts/main/ofl/nunito/Nunito%5Bwght%5D.ttf'
curl -fL -o assets/fonts/OFL.txt        'https://raw.githubusercontent.com/google/fonts/main/ofl/nunito/OFL.txt'
ls -l assets/fonts            # ttf about 277 KB
file assets/fonts/Nunito-wght.ttf   # TrueType font data
head -3 assets/fonts/OFL.txt  # Copyright … The Nunito Project Authors
shasum -a 256 assets/fonts/*  # paste into the report
```
If the download fails, stop and report; do not substitute another font or add `google_fonts`.

`pubspec.yaml`, under the existing `flutter:` key (keep `uses-material-design: true`):
```yaml
  assets:
    - assets/fonts/OFL.txt
  fonts:
    - family: Nunito
      fonts:
        - asset: assets/fonts/Nunito-wght.ttf
```

`ios/Runner/Info.plist`: set the array under `UISupportedInterfaceOrientations` to the single entry `UIInterfaceOrientationPortrait`. Leave `UISupportedInterfaceOrientations~ipad` untouched (D22).

---

## 2. Domain (pure Dart — no `flutter`, `sqflite`, `get_it`, `injectable` imports)

### `lib/core/failure.dart`
```dart
sealed class Failure implements Exception {
  const Failure(this.message);
  final String message;   // user-facing, shown inline
}
final class StorageFailure extends Failure {
  const StorageFailure() : super("Couldn't save. Try again.");
}
final class CorruptSession extends Failure {
  const CorruptSession() : super("Couldn't restore the last game");
}
```

### `lib/features/session/domain/entities/session.dart`
```dart
enum Phase { ready, revealed, challenge }   // .name is the SQL value
enum Mode { truth, dare }                   // .name is the SQL value

final class Player  { const Player({required this.seat, this.name}); final int seat; final String? name; }
final class Outcome { const Outcome({required this.taker, required this.giver}); final int taker, giver; }

final class Session {
  const Session({
    required this.id, required this.startedAtMs, required this.players,
    this.round = 1, this.phase = Phase.ready, this.outcome, this.mode,
  });
  final String id;
  final int startedAtMs;            // epoch ms UTC
  final List<Player> players;       // index == seat
  final int round;
  final Phase phase;
  final Outcome? outcome;
  final Mode? mode;

  int get playerCount => players.length;
  bool get isValid;                 // see below
  Session revealed(Outcome o);      // phase revealed, outcome o, mode null
  Session chose(Mode m);            // phase challenge, mode m
  Session nextRound();              // round + 1, phase ready, outcome null, mode null
  Session withPlayers(List<Player> p);
}
```
- All four classes: hand-written `==` / `hashCode` (`Object.hash`, `Object.hashAll` for the list; compare the list with a private loop — no `collection`, no `listEquals`).
- `isValid` is the single source of the invariants that A6 expresses in SQL plus what SQL cannot express:
  `playerCount` in 2…60; `round >= 1`; `players[i].seat == i` for all i; every name is `null` or equals `normalizeName(name)`; `ready` ⇒ outcome and mode null; `revealed` ⇒ outcome non-null, mode null; `challenge` ⇒ both non-null; outcome non-null ⇒ `isValidPair(playerCount, taker, giver)`.
- The four transition methods return new instances; they do not validate (the bloc guards phases).

### `lib/features/session/domain/rules/selection.dart`
```dart
const double tau = 2 * pi;

double seatAngle(int seat, int n) => tau * seat / n;      // 0 = twelve o'clock, clockwise
double normalizeAngle(double a) => (a % tau + tau) % tau;

/// Even n: one seat. Odd n: the two nearest-opposite seats, floor first.
List<int> oppositeSeats(int n, int taker);

/// Throws RangeError unless 2 <= n <= 60 (validation must survive release builds).
Outcome pickRoles(int n, Random rng);

bool isValidPair(int n, int taker, int giver);

final class SpinPlan {
  const SpinPlan({required this.start, required this.end, required this.turns, required this.durationMs});
  final double start, end;   // radians; end is NOT normalised
  final int turns, durationMs;
  // == / hashCode
}

SpinPlan spinPlan({required double current, required int taker, required int n, required Random rng});
```
Exact behaviour (tests depend on the RNG call order):
- `oppositeSeats`: even → `[(taker + n ~/ 2) % n]`; odd → `[(taker + n ~/ 2) % n, (taker + (n + 1) ~/ 2) % n]`. N = 2 falls out of the even rule (`1 − taker`).
- `pickRoles`: `RangeError.checkValueInInterval(n, 2, 60, 'n')`; `taker = rng.nextInt(n)`; `opp = oppositeSeats(n, taker)`; `giver = opp.length == 1 ? opp[0] : (rng.nextBool() ? opp[0] : opp[1])`. One `nextInt`, then one `nextBool` only for odd n.
- `isValidPair`: both in `0..n-1`, n in 2…60, and `oppositeSeats(n, taker).contains(giver)` (D16).
- `spinPlan`: `delta = normalizeAngle(seatAngle(taker, n) - normalizeAngle(current))`; `turns = 5 + rng.nextInt(2)`; `end = current + turns * tau + delta`; `durationMs = (4400 + (turns - 5) * 600 + (delta / tau) * 400).round()`; `start = current`. One `nextInt(2)`.

### `lib/features/session/domain/rules/labels.dart`
```dart
/// Trim; empty -> null; longer than 40 code points -> first 40.
String? normalizeName(String? raw);
// ponytail: truncates by rune, can split an emoji ZWJ sequence; switch to
// grapheme clusters if that ever matters. Runes match SQLite length().

/// "Player 7" or "Riya · P7". Seat number is always kept.
String displayLabel(Player p);

/// Name only if non-null and unique among all players (trimmed, case-insensitive), else "Player N".
String spokenName(Session s, int seat);

/// revealed: "<giver>, give a challenge to <taker>."
/// challenge: "<taker> chose Truth." / "<taker> chose Dare."
/// ready: null.   Uses spokenName.
String? speechLine(Session s);
```
The separator in `displayLabel` is U+00B7 with one space each side. Display seat is `seat + 1`.

### `lib/features/session/domain/session_repository.dart`
```dart
abstract interface class SessionRepository {
  /// null when nothing is stored. Throws CorruptSession (after deleting the rows) or StorageFailure.
  Future<Session?> load();
  /// Replaces any stored session. Creates id and start time. Returns round 1, phase ready.
  Future<Session> start(List<Player> players);
  /// Single UPDATE of round, phase, taker, giver, mode.
  Future<void> saveRound(Session session);
  /// Transaction: player_count + all player rows. Keeps the id.
  Future<void> replacePlayers(String id, List<Player> players);
  /// DELETE FROM session (players cascade).
  Future<void> end();
}
```
All write methods throw `StorageFailure` on any database error.

### Tests for this step
- `test/selection_test.dart` — for every n in 2…60 and seeds 0…199: taker in range, `giver != taker`, `isValidPair` true; even n: giver is the exact opposite; odd n: giver in `oppositeSeats`, and across the seeds both candidates occur for at least n = 3, 5, 7, 59; n = 2: `giver == 1 - taker`; `pickRoles(1, …)` and `pickRoles(61, …)` throw `RangeError`; for n = 7, 2000 draws hit every seat as taker; `isValidPair` rejects equal seats, out-of-range seats, and a non-opposite pair such as `(8, 0, 3)`; `oppositeSeats(5, 0) == [2, 3]`, `oppositeSeats(8, 2) == [6]`.
- `test/rotation_test.dart` — `seatAngle(0, n) == 0`, `seatAngle(2, 8) == pi / 2`; `normalizeAngle` of negative and > 2π values; for n in {2, 3, 5, 7, 8, 59, 60}, several seeds, and `current` in {0, 1.0, 6.2, 13.7}: `normalizeAngle(end)` equals `seatAngle(taker, n)` within 1e-9 (compare circularly so 0 and 2π match); `end - start` in `[5·tau, 7·tau)`; `turns` in {5, 6}; `durationMs` equals the formula and lies in 4400…5400; `start == current`.
- `test/labels_test.dart` — `normalizeName`: `null`, `''`, `'  '` → null; `' Riya '` → `'Riya'`; a 45-rune string → 40 runes; a string of 41 astral-plane characters stays valid UTF-16. `displayLabel`: unnamed and named. `spokenName`: unique name used; duplicate (also differing only by case) → "Player N" for both; unnamed → "Player N". `speechLine`: revealed, challenge (both modes), ready → null. `Session.isValid`: one valid session per phase; each invariant violated once.

---

## 3. Data and DI

### `lib/features/session/data/session_db.dart`
Top-level only, no class:
```dart
const int sessionDbVersion = 1;
const List<String> sessionSchema = [ /* the two CREATE TABLE statements of spec A6, verbatim */ ];

Future<Database> openSessionDb({DatabaseFactory? factory, String path = 'spinfolk.db'});
```
- Copy both `CREATE TABLE` statements from `docs/spec-v2.md` A6 character for character (comments may be dropped). Do not reorder or rename columns or constraints.
- `openSessionDb`: `final f = factory ?? databaseFactory;` then `f.openDatabase(path, options: OpenDatabaseOptions(version: sessionDbVersion, onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'), onCreate: (db, _) async { for (final sql in sessionSchema) { await db.execute(sql); } }, onDowngrade: onDatabaseDowngradeDelete))`.
- Wrap the open in `try`; `on DatabaseException` → `await f.deleteDatabase(path)` and open once more (an unreadable file must not brick the app; the session is disposable game state). Comment that in one line.
- No `onUpgrade` yet: there is no version 2. Add it with the first migration.
- The relative path is resolved by sqflite against its databases directory (verified); do not add `path`.

### `lib/features/session/data/session_repository_impl.dart`
```dart
@LazySingleton(as: SessionRepository)
class SessionRepositoryImpl implements SessionRepository {
  SessionRepositoryImpl(this._db);
  final Database _db;
}
```
- `load()`: read `session` (0 or 1 row) and `player` ordered by `seat`. No row → `null`. Map to `Session` (enum via `values.byName`; `outcome` when `taker` is non-null). If mapping throws (`ArgumentError`, `TypeError`), or `player_count != players.length`, or `!session.isValid` → `await _db.delete('session')` then `throw const CorruptSession()`. `DatabaseException` anywhere → `throw const StorageFailure()`.
- `start(players)`: id = 16 bytes from `Random.secure()` as 32 lowercase hex; `startedAtMs = DateTime.now().toUtc().millisecondsSinceEpoch`. In `_db.transaction`: `delete('session')`; insert the session row (`round 1`, `phase 'ready'`, `player_count`); insert players with one `Batch` (`commit(noResult: true)`). Return the `Session`.
- `saveRound(s)`: `final n = await _db.update('session', {'round': s.round, 'phase': s.phase.name, 'taker': s.outcome?.taker, 'giver': s.outcome?.giver, 'mode': s.mode?.name}, where: 'id = ?', whereArgs: [s.id]); if (n != 1) throw const StorageFailure();`
- `replacePlayers(id, players)`: in `_db.transaction`: update `player_count` (`where id = ?`, must affect 1 row, else throw inside the transaction so it rolls back); delete that session's players; batch-insert the new ones.
- `end()`: `_db.delete('session')`.
- One private helper wraps each public method body: `on DatabaseException catch (_) { throw const StorageFailure(); }`. `CorruptSession` passes through untouched.
- Never write the string `spinning` to the database. There is no code path that could; the CHECK also refuses it.

### `lib/core/di/injection.dart`
- `@InjectableInit() Future<void> configureDependencies() => getIt.init();` (delete the "synchronous until…" comment).
- Add to `CoreModule`:
  ```dart
  @preResolve
  @singleton
  Future<Database> get database => openSessionDb();
  ```
- `SharedPreferencesWithCache` is **not** added (Phase 3).

Run codegen. Expect `injection.config.dart` to become `Future<GetIt> init(...) async` and to register `Database` and `SessionRepository`.

### `test/session_repository_test.dart`
`setUpAll(sqfliteFfiInit)`; per test `db = await openSessionDb(factory: databaseFactoryFfi, path: inMemoryDatabasePath)`; `tearDown(() => db.close())` (closing an in-memory database discards it, which isolates tests).
- `PRAGMA foreign_keys` returns 1; `PRAGMA user_version` returns 1; both tables exist.
- `load()` on empty → null.
- `start` then `load` round-trips players (with and without names), round 1, phase ready; id matches `^[0-9a-f]{32}$`.
- `start` twice → exactly one `session` row, players of the second call only.
- `saveRound` for revealed → challenge → next round; each `load()` equals the saved `Session`.
- `saveRound` with an unknown id → `StorageFailure`.
- `replacePlayers` 8 → 5 and 5 → 60: count and rows match, id unchanged.
- `end()` → both tables empty (cascade).
- Raw SQL the schema must refuse (each `throwsA(isA<DatabaseException>())`): `phase = 'spinning'`; `revealed` with null taker; `taker = giver`; `taker = player_count`; `player_count = 1` and `61`; a second session row; a player with `seat = 60`; a name of 41 characters; an empty name.
- Corrupt but SQL-legal data: after `start`, `DELETE FROM player WHERE seat = 1` → `load()` throws `CorruptSession`, and `SELECT count(*)` on both tables is 0. Same for a non-opposite pair written with raw `UPDATE` (for example n = 8, taker 0, giver 3).

If the test cannot load SQLite on this machine (native-asset hook), paste the error and report; do not change dependencies.

---

## 4. `SessionBloc` — `lib/features/session/presentation/bloc/`

Three files: `session_bloc.dart` with `part 'session_event.dart';` and `part 'session_state.dart';`.

### `session_state.dart`
```dart
sealed class SessionState { const SessionState(); }
final class SessionLoading extends SessionState { const SessionLoading(); }
final class NoSession extends SessionState { const NoSession({this.notice}); final String? notice; }
final class ResumePrompt extends SessionState { const ResumePrompt(this.session, {this.failure}); final Session session; final Failure? failure; }
final class SessionActive extends SessionState {
  const SessionActive({
    required this.session, this.spinning = false, this.spinPlan,
    this.orientation = 0, this.failure, this.replayCount = 0,
  });
  final Session session;
  final bool spinning;
  final SpinPlan? spinPlan;      // non-null exactly while spinning
  final double orientation;      // radians, memory only
  final Failure? failure;
  final int replayCount;         // bumped by ReplayRequested; Phase 3's Announcer watches it
}
```
Hand-written `==` / `hashCode` on all. No `copyWith` with nullable parameters (it cannot clear a field); build each new `SessionActive` explicitly. `Failure` subclasses are `const`, so identity comparison is enough.

### `session_event.dart`
`sealed class SessionEvent` with `final class` subtypes, all `const`: `AppStarted`, `ResumeConfirmed`, `SessionStarted(int count, List<String?> names)`, `SpinRequested`, `SpinAnimationFinished`, `ModeChosen(Mode mode)`, `Passed`, `NextRoundRequested`, `PlayersEdited(int count, List<String?> names)`, `EndConfirmed`, `AppBackgrounded`, `SessionLinkOpened(String id)`, `ReplayRequested`.

### `session_bloc.dart`
```dart
@lazySingleton
class SessionBloc extends Bloc<SessionEvent, SessionState> {
  SessionBloc(this._repo, this._rng) : super(const SessionLoading()) {
    // One handler, strictly sequential: every event sees the state left by the
    // previous one, so no re-checks after awaits (stdlib stand-in for
    // bloc_concurrency.sequential).
    on<SessionEvent>(_onEvent, transformer: (events, mapper) => events.asyncExpand(mapper));
  }
  final SessionRepository _repo;
  final Random _rng;
}
```
`_onEvent` is an exhaustive `switch` on the sealed event. Rules that hold for every handler:
- An event that does not apply to the current state is ignored silently (return without emitting).
- Repository calls are wrapped in `try { … } on Failure catch (f) { … }`.
- Persist first, emit after (D2). The only exception is `SpinRequested`.
- A successful emit always carries `failure: null`.

Private helper used by start and edit: `List<Player>? _players(int count, List<String?> names)` → `null` if `count` is outside 2…60 or `names.length != count`; else `[for i in 0..count-1: Player(seat: i, name: normalizeName(names[i]))]`.

| Event | Applies when | Does | On `Failure` |
|---|---|---|---|
| `AppStarted` | `SessionLoading` | `load()` → `null`: `NoSession()`; session: `ResumePrompt(session)` | `NoSession(notice: const CorruptSession().message)` for both failure types |
| `ResumeConfirmed` | `ResumePrompt` | `SessionActive(session, orientation: outcome == null ? 0 : seatAngle(taker, n))` | — |
| `SessionStarted` | `NoSession` and `_players` non-null | `start(players)` → `SessionActive(session)` | `NoSession(notice: f.message)` |
| `SpinRequested` | `SessionActive`, `!spinning`, phase `ready` | `o = pickRoles(n, _rng)`; `plan = spinPlan(current: orientation, taker: o.taker, n: n, rng: _rng)`; `next = session.revealed(o)`; **emit** `SessionActive(next, spinning: true, spinPlan: plan, orientation: orientation)` **before the first await**; then `await saveRound(next)` | emit `SessionActive(previous ready session, orientation: orientation, failure: f)` |
| `SpinAnimationFinished` | `SessionActive`, `spinning` | emit `spinning: false`, `spinPlan: null`, `orientation: normalizeAngle(plan.end)` | — |
| `AppBackgrounded` | `SessionActive`, `spinning` | identical to `SpinAnimationFinished` (share one private method) | — |
| `ModeChosen(m)` | `SessionActive`, `!spinning`, phase `revealed` | `next = session.chose(m)`; `saveRound(next)`; emit | re-emit current state with `failure: f` |
| `Passed` | `SessionActive`, `!spinning`, phase `revealed` or `challenge` | `next = session.nextRound()`; `saveRound(next)`; emit (orientation kept) | re-emit with failure |
| `NextRoundRequested` | `SessionActive`, `!spinning`, phase `challenge` | same as `Passed` (share the method) | re-emit with failure |
| `PlayersEdited` | `SessionActive`, `!spinning`, phase `ready`, `_players` non-null | `replacePlayers(id, players)`; emit `session.withPlayers(players)`, `orientation: 0` | re-emit with failure |
| `EndConfirmed` | `ResumePrompt`, or `SessionActive` with `!spinning` | `end()`; emit `NoSession()` | re-emit same state type with `failure: f` |
| `SessionLinkOpened(id)` | `ResumePrompt` with `session.id == id` | same as `ResumeConfirmed` (D24) | — |
| `ReplayRequested` | `SessionActive`, `!spinning`, phase not `ready` | emit with `replayCount + 1` | — |

Notes:
- "Never re-roll": `pickRoles` is called in exactly one place, behind the `phase == ready` guard.
- `PlayersEdited` resets orientation to 0 because seat angles change with N.
- After the `SpinRequested` failure path the RNG has advanced; that is fine (no outcome was stored).
- No `BuildContext`, no navigation, no speech, no Live Activity calls here.

### `test/support/fake_session_repository.dart`
In-memory `SessionRepository`: `Session? stored`; `Failure? loadError`; `bool failWrites`; `final List<String> calls` (method names in order). `start` returns `Session(id: 'test', startedAtMs: 0, players: players)`. When `failWrites` is true every write throws `const StorageFailure()` and leaves `stored` untouched.

### `test/session_bloc_test.dart`
Plain `flutter_test`. Helper: `Future<void> settle() => pumpEventQueue();` after each `add`. Collect `bloc.stream` into a list where emission order matters. Seeded `Random(1)`.
- `AppStarted`: empty → `NoSession()`; stored session → `ResumePrompt`; `loadError = CorruptSession()` → `NoSession` with notice "Couldn't restore the last game"; second `AppStarted` ignored.
- `ResumeConfirmed`: ready session → orientation 0; revealed session → orientation `seatAngle(taker, n)`, `spinning == false`.
- `SessionStarted(8, 8 nulls)` → `SessionActive`, round 1, ready, `calls == ['load', 'start']`; `count` 1, 61, and a names list of the wrong length are ignored; names are normalised (`' Riya '` → `'Riya'`, `''` → null); write failure → `NoSession` with the storage message.
- Spin: first emission after `SpinRequested` has `spinning == true`, a plan, and session phase `revealed`; `stored.phase == revealed` after settle; `SpinAnimationFinished` → `spinning == false`, `spinPlan == null`, `orientation ≈ seatAngle(taker, n)`.
- **Double spin**: `bloc..add(SpinRequested())..add(SpinRequested())` → `calls.where((c) => c == 'saveRound').length == 1`, exactly one spinning emission, and the outcome equals `pickRoles(n, Random(1))` computed in the test.
- Spin while `revealed` or `challenge` is ignored (outcome unchanged, no write).
- Spin with `failWrites` → final state phase `ready`, `spinning == false`, `failure is StorageFailure`, `stored.phase == ready`; then `failWrites = false`, spin again succeeds and `failure == null`.
- `AppBackgrounded` while spinning → same result as finished; while not spinning → no emission.
- `SpinAnimationFinished` when not spinning → no emission.
- `ModeChosen(truth)` → `challenge`; ignored in `ready`; write failure keeps `revealed` + failure.
- `Passed` from `revealed` and from `challenge` → round + 1, `ready`, no outcome, no mode; ignored in `ready`. `NextRoundRequested` only from `challenge`.
- `PlayersEdited(5, …)` in `ready` → 5 players, same id, same round; ignored in `revealed` and while spinning; failure keeps the old players.
- `EndConfirmed` from active and from `ResumePrompt` → `NoSession`; ignored while spinning; failure keeps the state with `failure` set.
- `SessionLinkOpened`: matching id in `ResumePrompt` → active; other id → ignored; in active → ignored.
- `ReplayRequested`: increments in `revealed`; ignored in `ready`.
- A full loop for n in {2, 3, 5, 7, 59, 60}: start, 3 × (spin, finish, choose or pass, next) — after every step `stored == state.session` and `stored.isValid`.

---

## 5. `SetupCubit` — extend `lib/features/setup/presentation/cubit/setup_cubit.dart`

```dart
final class SetupState {
  const SetupState({this.count = _initialCount, this.names = const {}, this.draft});
  final int count;
  final Map<int, String> names;    // seat -> normalised name; seats >= count are kept but unused
  final Map<int, String>? draft;   // non-null only while the Names page is open (raw text)
  List<String?> get namesForCount => [for (var i = 0; i < count; i++) names[i]];
  int get namedCount => namesForCount.whereType<String>().length;
}
```
Top of file:
```dart
// Lets the simulator gate start at an exact player count (the native wheel
// cannot be set to 59 by automation). Normal builds get 8.
const int _envCount = int.fromEnvironment('SPINFOLK_INITIAL_COUNT', defaultValue: 8);
const int _initialCount = _envCount < 2 ? 2 : (_envCount > 60 ? 60 : _envCount);
```
Methods (all synchronous, no context):
- `countChanged(int)` — unchanged behaviour, keeps `names` and `draft`.
- `namesOpened()` — `draft = Map.of(names)`.
- `draftChanged(int seat, String text)` — ignore if `draft == null` or seat outside `0..59`; store the raw text.
- `namesSaved()` — `names = {for each draft entry: seat -> normalizeName(text)}` minus nulls; `draft = null`.
- `namesCancelled()` — `draft = null`.
- `seed(int count, List<String?> names)` — for Edit Players; ignore if count is out of range; replaces `count` and `names`, clears `draft`.
- `reset()` — `emit(const SetupState())`.

`==` / `hashCode` must compare the maps by content (private helper loop). The cubit imports `labels.dart` from the session domain; that is allowed (presentation → domain).

Extend `test/setup_cubit_test.dart`: default count 8; draft flow (open, change, save normalises and drops blanks; cancel discards); a name survives count 8 → 4 → 8; `namesForCount` length equals count; `seed`; `reset`; out-of-range `draftChanged` and `seed` ignored.

---

## 6. Router, navigator, app, main

### `lib/app/bloc_listenable.dart`
```dart
class BlocListenable extends ChangeNotifier {
  BlocListenable(Stream<Object?> stream) { _sub = stream.listen((_) => notifyListeners()); }
  late final StreamSubscription<Object?> _sub;
  @override
  void dispose() { _sub.cancel(); super.dispose(); }
}
```

### `lib/app/router.dart`
```dart
/// Pure: where a location must go for a session state, or null to stay.
String? sessionRedirect(SessionState state, Uri uri);

GoRouter buildRouter(SessionBloc bloc);   // also used by tests

@module
abstract class RouterModule {
  @lazySingleton
  GoRouter router(SessionBloc bloc) => buildRouter(bloc);
}
```
`sessionRedirect` implements the table in `prd.md` §7 exactly, using `uri.path` and `uri.queryParameters['edit'] == '1'`.

`buildRouter`:
```dart
GoRouter(
  initialLocation: '/new',
  refreshListenable: BlocListenable(bloc.stream),
  redirect: (_, state) => sessionRedirect(bloc.state, state.uri),
  routes: [
    GoRoute(path: '/new',    builder: (_, s) => NewGamePage(editing: _editing(s))),
    GoRoute(path: '/names',  builder: (_, s) => AddNamesPage(editing: _editing(s))),
    GoRoute(path: '/resume', builder: (_, _) => const ResumePage()),
    GoRoute(path: '/game',   builder: (_, _) => const GamePage(), routes: [
      GoRoute(path: 'settings', pageBuilder: (_, s) => _overlay(s, const SettingsSheetPage(), const Color(0x80000000))),
      GoRoute(path: 'end',      pageBuilder: (_, s) => _overlay(s, const EndConfirmPage(),   const Color(0x8C040810))),
    ]),
  ],
)
```
`_editing(s)` → `s.uri.queryParameters['edit'] == '1'`.
`_overlay` returns `CustomTransitionPage(key: s.pageKey, opaque: false, barrierDismissible: true, barrierColor: color, transitionDuration: Tokens.panelEnter, reverseTransitionDuration: Tokens.panelEnter, child: child, transitionsBuilder: …)`. The builder reads `MediaQuery.disableAnimationsOf(context)`: on → `FadeTransition`; off → `SlideTransition` from `Offset(0, 1)` with `Curves.easeOutCubic`. Sheets and dialogs are these routes; nothing else.

### `lib/app/app_navigator.dart`
```dart
@lazySingleton
class AppNavigator {
  AppNavigator(this._router);
  final GoRouter _router;

  void setup({bool editing = false}) => _router.go(editing ? '/new?edit=1' : '/new');
  void names({bool editing = false}) => _router.go(editing ? '/names?edit=1' : '/names');
  void game() => _router.go('/game');           // also closes the sheet and the dialog
  void settings() => _router.go('/game/settings');
  void confirmEnd() => _router.go('/game/end');
}
```
(The spec's `pushNames / openSettings / confirmEnd / pop` map to `names / settings / confirmEnd / game`; `go` instead of `push` per D6.)

### `lib/app/app.dart`
```dart
MultiRepositoryProvider(
  providers: [RepositoryProvider<AppNavigator>.value(value: getIt<AppNavigator>())],
  child: MultiBlocProvider(
    providers: [
      BlocProvider<SessionBloc>.value(value: getIt<SessionBloc>()),
      BlocProvider<SetupCubit>(create: (_) => getIt<SetupCubit>()),
    ],
    child: BlocListener<SessionBloc, SessionState>(
      // "Clears N players": old names must not reappear on New Game.
      listenWhen: (a, b) => b is NoSession && a is! SessionLoading,
      listener: (context, _) => context.read<SetupCubit>().reset(),
      child: MaterialApp.router( … existing arguments … ),
    ),
  ),
)
```
Pages obtain the navigator with `context.read<AppNavigator>()`, never `getIt` (keeps pages testable).

### `lib/main.dart`
```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Nunito'], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  await configureDependencies();
  final bloc = getIt<SessionBloc>()..add(const AppStarted());
  // The native launch screen covers this; the router never sees SessionLoading.
  if (bloc.state is SessionLoading) {
    await bloc.stream.firstWhere((s) => s is! SessionLoading);
  }
  runApp(const SpinfolkApp());
}
```
No `Announcer`, no `LiveActivitySync`, no lifecycle listener.

### `test/router_redirect_test.dart`
Pure calls to `sessionRedirect`, one expectation per cell of the table in `prd.md` §7, including: active + `/new` → `/game`; active ready + `/new?edit=1` → null; active revealed + `/new?edit=1` → `/game`; active spinning + `/names?edit=1` → `/game`; `ResumePrompt` + `/game/end` → null; `ResumePrompt` + `/game` → `/resume`; `NoSession` + `/game/settings` → `/new`.

---

## 7. Tokens and shared UI

### `lib/app/tokens.dart` — change the import to `package:flutter/painting.dart` and add
- Colors: `bgSheet 0xFF0F192C`, `dot 0xFF3A4D74`, `bottleFill 0x29DDE6F2` (0.16), `bottleStroke 0xBFE8EEF7` (0.75), `scrim 0x80000000`.
- Durations: `panelEnter = Duration(milliseconds: 320)`, `reducedSpin = Duration(milliseconds: 600)`, `pulse = Duration(milliseconds: 1200)`.
- `spinCurve = Cubic(0.15, 0.60, 0.10, 1.00)`.
- Sizes: `touch = 44.0`, `barPrimary = 64.0`, `barSecondary = 50.0`, `barGap = 10.0`, `passWidth = 104.0`, `pickerHeight = 216.0`, `maxContentWidth = 480.0`.
- Text styles (system font, `color: textPrimary` unless noted): `largeTitle` 34 / w700 / −0.5 tracking; `title2` 22 / w700; `headline` 17 / w600; `body` 17; `subhead` 15 / `textSecondary`; `footnote` 13 / `textTertiary`; `caption` 12 / w700 / 1.3 tracking.
- `static TextStyle numeral(double size, {Color color = textPrimary})` → `fontFamily: 'Nunito'`, `fontWeight: FontWeight.w800`, `fontVariations: const [FontVariation('wght', 800)]`, `fontFeatures: const [FontFeature.tabularFigures()]`, `height: 1.15`. This is the only place Nunito is named.

### `lib/app/ui.dart` — three small widgets, nothing else
- `PageFrame({required Widget child})` — `SafeArea` → `Center` → `ConstrainedBox(maxWidth: Tokens.maxContentWidth)` → `Padding(horizontal: Tokens.margin)`.
- `NoticeBanner(String text)` — full-width box, `bgRaised`, radius 14, padding 12 × 14, text 13 / `textSecondary`, `Semantics(liveRegion: true)`. Used for `NoSession.notice` and every `failure.message`.
- `double barScale(BuildContext context)` → `(MediaQuery.textScalerOf(context).scale(17) / 17).clamp(1.0, 1.5)` — multiplies island heights so native labels (clamped at `.accessibility2`) are not clipped.
- `TextScaler besideIsland(BuildContext context)` → `MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.5)` — for the two footnotes that share a fixed-height slot with an island (D21).

### `lib/app/logo_mark.dart`
`class LogoMark extends StatelessWidget { const LogoMark({this.size = 44, this.rotation = pi / 4}); }` → `CustomPaint(size: Size.square(size), painter: _LogoPainter(rotation))`, wrapped in `ExcludeSemantics`.
Geometry in a 100-unit box (scale by `size / 100`): 8 dots on radius 36 around the centre, radius 4.6, color `dot`; the dot nearest `rotation` is `taker` with radius 6.2, the opposite one `giver` with radius 6.2; bottle at the centre rotated by `rotation`, scale 0.27, body filled `0xF2E8EEF7` with no stroke, lip `RRect(-10, -100, 20, 12, r 4)` `taker`, base `RRect(-22, 70, 44, 14, r 6)` `giver`. Reuse `bottleBodyPath()` from `dial_painter.dart`.

---

## 8. Dial and spin stage — `lib/features/game/presentation/widgets/`

### `dial_painter.dart`
```dart
/// Bottle body in its own units: neck up, spans y -88..84, x -22..22.
Path bottleBodyPath();

class DialPainter extends CustomPainter {
  DialPainter({
    required this.n,
    required this.spin,          // 0..1 while spinning
    required this.pulse,         // 0..1 after reveal
    required this.orientation,   // resting bottle angle
    this.plan,                   // non-null only while spinning
    this.outcome,                // non-null only when revealed AND not spinning
    this.reduceMotion = false,
  }) : super(repaint: Listenable.merge([spin, pulse]));
}
```
`shouldRepaint(old)` compares `n`, `orientation`, `plan`, `outcome`, `reduceMotion`. Per-frame repaint comes from the listenable.

Body path (SVG from the artboards, translate literally with `moveTo/lineTo/cubicTo/quadraticBezierTo`):
`M -8,-88 L 8,-88 L 8,-40 C 8,-24 22,-18 22,0 L 22,72 Q 22,84 10,84 L -10,84 Q -22,84 -22,72 L -22,0 C -22,-18 -8,-24 -8,-40 Z`

Geometry, with `c` = centre, `side = size.shortestSide`, `R = side / 2 − 4`, `k = (R / 146).clamp(0.75, 1.2)` (multiplies every pixel constant below marked ×k), direction of angle `a` = `Offset(sin a, −cos a)`:
1. Disc: circle `R`, fill `bgSurface`, stroke `line` 1.5.
2. Inner ring: radius `R − 50×k`, `line`, width 1, dashes 2 on / 6 off. No dash API: draw short arcs in a loop, or dots. Build it once per painter instance (`late final Path`).
3. Seats, `θ(i) = seatAngle(i, n)`:
   - **n ≤ 12 (discs)**, centre on radius `R − 24×k`: idle disc radius 15×k, fill `bgRaised`, stroke `line` 1.5, number `i + 1` in `Tokens.numeral(14×k)` `textPrimary`. Selected (taker / giver): halo radius 25×k in the role color at 22 % opacity, disc radius 18×k filled with the role color, number in `bgBase`.
   - **n > 12 (ticks)**, from radius `R − 4` inward: normal length 8×k, `line`, width 2, round caps; every fifth seat (`i % 5 == 0`) length 13×k, `textSecondary`, with number `Tokens.numeral(10×k, color: textTertiary)` centred on radius `R − 42×k`; selected length 22×k, width 4, role color, with number `Tokens.numeral(12×k, role color)` on radius `R − 42×k` over a halo of radius 13×k at 22 %. Skip a fifth-seat label when it is within one seat of a selected seat (they would overlap).
   - Pulse: selected markers (disc + halo, or number + halo) are scaled by `1 + 0.18 · sin(π · ((pulse.value · 2) % 1))` about their own centre. At 0 and 1 the factor is exactly 1. No pulse when `reduceMotion`.
4. Odd-N arc (only when `outcome != null` and `n.isOdd`): radius `78 × s` (see `s` below), from the base direction `θ(taker) + π` the short way to `θ(giver)`, as round dots of diameter 3 every 7 px, color `giver`. The bottle is not bent.
5. Bottle: `s = 0.62 · R / 96`. `canvas.save(); translate(c); rotate(angle); scale(s)`; body fill `bottleFill`, stroke `bottleStroke` width 2.5; lip `RRect(-10, -98, 20, 10, r 3)` `taker`; base band `RRect(-14, 78, 28, 6, r 3)` `giver`; highlight line `(-12, 6) → (-12, 60)` white 35 %, width 5, round cap; `restore`.
   - `angle` when `plan == null`: `orientation`.
   - Spinning, normal motion: `plan.start + (plan.end − plan.start) · Tokens.spinCurve.transform(spin.value)`.
   - Spinning, `reduceMotion`: draw the bottle twice — at `plan.start` with opacity `1 − spin.value` and at `plan.end` with opacity `spin.value` (`saveLayer` with an alpha paint, or alpha-scaled paints).
6. Centre pin: circle radius 3×k, `textPrimary`.

Text: build the `TextPainter`s lazily once per painter instance (`late final`), never per frame. Dial labels use fixed sizes — they deliberately ignore the user's text scale (spec).

The painter is not allowed to read the outcome while spinning; the caller passes `outcome: null` then (D15).

### `spin_stage.dart` — the only `StatefulWidget`
```dart
class SpinStage extends StatefulWidget { const SpinStage({super.key}); … }

class _SpinStageState extends State<SpinStage> with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this)..addStatusListener(_onSpinStatus);
  late final AnimationController _pulse = AnimationController(vsync: this, duration: Tokens.pulse);
}
```
- **No `setState`. No other fields.**
- `initState`: if the bloc is already `SessionActive` with `spinning` (the stage was mounted mid-spin and cannot know the progress) → `context.read<SessionBloc>().add(const SpinAnimationFinished())`.
- `_onSpinStatus`: on `AnimationStatus.completed` → `HapticFeedback.mediumImpact()` then `add(const SpinAnimationFinished())`. This is the only haptic, so the backgrounded path gives none.
- `dispose`: dispose both controllers.
- `build`:
  ```dart
  final reduce = MediaQuery.disableAnimationsOf(context);   // read in build only
  return BlocConsumer<SessionBloc, SessionState>(
    listenWhen: (a, b) => _spinning(a) != _spinning(b),
    listener: (context, s) {
      if (s is SessionActive && s.spinning) {
        _pulse.value = 0;
        _spin.duration = reduce ? Tokens.reducedSpin : Duration(milliseconds: s.spinPlan!.durationMs);
        _spin.forward(from: 0);
      } else {
        _spin.stop();
        if (!reduce && s is SessionActive && s.session.outcome != null) _pulse.forward(from: 0);
      }
    },
    builder: (context, s) { … },
  );
  ```
  Builder: not `SessionActive` → `const SizedBox.shrink()`. Otherwise
  `Semantics(label: <label>, image: true, child: ExcludeSemantics(child: CustomPaint(size: Size.infinite, painter: DialPainter(n: …, spin: _spin, pulse: _pulse, orientation: s.orientation, plan: s.spinning ? s.spinPlan : null, outcome: s.spinning ? null : s.session.outcome, reduceMotion: reduce))))`.
- Semantics label (exact strings, Maestro depends on them): ready → `Dial, N players, ready to spin`; spinning → `Bottle spinning`; revealed / challenge → `Taker <displayLabel(taker)>, Giver <displayLabel(giver)>`.

### `role_cards.dart`
`class RoleCards extends StatelessWidget { const RoleCards({required this.session}); }` — requires `session.outcome != null`.
- One card per role: `bgSurface`, `line` border, radius 18, padding 12 × 14; a 40-pt circle in the role color holding the role icon drawn in `bgBase` (taker: up arrow — `M12 3 L12 21 M6 9 L12 3 L18 9`, stroke 2.6, round; giver: stem `M12 3 L12 15` plus bar `RRect(6, 17, 12, 4, r 2)`; 24-unit box scaled to 20 pt; one small private painter); then a column: caption in the role color, the name in `Tokens.numeral(22)` on one line with ellipsis, a 14-pt `textSecondary` subtitle.
- Unnamed player: caption `TAKER` / `GIVER`, big text `Player 7`. Named player: caption `TAKER · P7`, big text the name.
- Layout: **stacked** (full width, 10 gap) when either player is named or `MediaQuery.textScalerOf(context).scale(1) > 1.3`; otherwise **side by side** (two equal `Expanded` cards, 10 gap). Subtitles: side by side `Picks` / `Asks`; stacked `Picks Truth or Dare` / `Gives the challenge`.
- Each card: `Semantics(label: 'Taker, ${displayLabel(p)}')` (or `Giver, …`) with its children excluded, so the full name is always announced.
- Role is always text + icon + color, never color alone.

### `test/dial_painter_test.dart`
For n in {2, 3, 5, 7, 12, 13, 59, 60}, with and without an outcome (from `pickRoles(n, Random(1))`), spinning (plan set, `AlwaysStoppedAnimation(0.5)`) and resting, `reduceMotion` on and off, sizes 120 and 350: `painter.paint(Canvas(PictureRecorder()), Size.square(x))` completes without throwing. `shouldRepaint` is false for equal inputs and true when `outcome` changes. `bottleBodyPath().getBounds()` is `Rect.fromLTRB(-22, -88, 22, 84)`.

---

## 9. Pages

Common: `Scaffold(backgroundColor: Tokens.bgBase)`; body inside `PageFrame`; `BlocBuilder` / `BlocSelector` for all state; open the matching artboard in `docs/design/project/` and copy sizes, spacing and copy from it. Glass on the artboard that is not a native island becomes a solid `bgRaised` surface with a 1-px `line` border in the same shape (D9). Never put a Flutter widget on top of an island on the same page; never wrap an island in `ClipRRect`, `Opacity` or a transform.

Island heights always go through `barScale(context)` (written `s` below).

Overflow rule for every page: only islands, their adjacent footnote, and header rows are pinned; **all other content sits in a `SingleChildScrollView` inside an `Expanded`/`Flexible`**, so large text scrolls instead of overflowing. `layout_test` (§11) enforces this.

### 9.1 `lib/features/setup/presentation/pages/new_game_page.dart` — `NewGamePage({required bool editing})` · artboard `NewGame`
`Column`:
1. `Expanded(SingleChildScrollView(Column))`:
   - If `editing`: a left-aligned `TextButton` "Cancel" → `nav.game()`. Otherwise the logo row: `LogoMark(size: 44)` + "Spinfolk" in `Tokens.numeral(30)`.
   - Title (`largeTitle`): `New Game`, or `Edit Players` when editing. Subtitle (`body`, `textSecondary`): `How many players?`.
   - `NoticeBanner` when the session state is `NoSession` with a `notice` (not when editing).
   - `SizedBox(height: Tokens.pickerHeight, child: NativePicker(min: SetupCubit.minPlayers, max: SetupCubit.maxPlayers, value: count, onChanged: cubit.countChanged))`.
   - Seating card (`bgSurface`, `line`, radius 20, padding 16): `LogoMark(size: 64, rotation: 0)` + text (15 / 21, `textSecondary`): `Sit in a circle in number order, going clockwise. Player 1 sits at the top of the dial.`
   - Link (min height 44): `Add Names` in `taker` color w600 + ` (optional)` in `textTertiary`; when at least one seat is named show `Edit Names · K named` instead. Tap → `cubit.namesOpened(); nav.names(editing: editing);`
2. Pinned bottom: `SizedBox(height: Tokens.barPrimary * s, child: NativeActionBar(items: [primary]))` — not editing: id `start`, label `Start Session` → `bloc.add(SessionStarted(count, setup.namesForCount))`; editing: id `save`, label `Save Players` → `bloc.add(PlayersEdited(count, setup.namesForCount)); nav.game();`. Below it a centred footnote: `Players stay numbered unless you add names.` Bottom padding 8.

### 9.2 `lib/features/setup/presentation/pages/add_names_page.dart` — `AddNamesPage({required bool editing})` · artboard `AddNames`
- If `setup.draft == null` (deep entry or one stale frame) → `const SizedBox.shrink()` inside the scaffold.
- Header row: `TextButton` `Cancel` → `cubit.namesCancelled(); nav.setup(editing: editing);` · title `Names` (`headline`) · `TextButton` `Done` (w700) → `cubit.namesSaved(); nav.setup(editing: editing);`. Each of the three in a `Flexible` with one-line ellipsis so large text cannot overflow the row.
- Intro, first child of the scroll column (15 / 21, `textSecondary`): `Clockwise from Player 1. Blank stays numbered. Matching names get their seat number added.`
- `Expanded(SingleChildScrollView(Column[intro, card, footnote]))` — the intro and footnote scroll with the rows (at the largest text size they would otherwise fill the screen). The card (`bgSurface`, `line`, radius 20, clipped) is a plain `Column` of `count` rows with `line` dividers (at most 60, built eagerly — cheap, and it keeps typed text alive while scrolling); row min height 54: a 30-pt `bgRaised` circle with the seat number (`Tokens.numeral(14)`), then
  `TextFormField(key: ValueKey(seat), initialValue: draft[seat] ?? '', onChanged: (t) => cubit.draftChanged(seat, t), inputFormatters: [LengthLimitingTextInputFormatter(40)], textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.next, autocorrect: false, decoration: InputDecoration(border: InputBorder.none, hintText: 'Player ${seat + 1}', hintStyle: …textTertiary), style: Tokens.body)`, wrapped in `Semantics(label: 'Name for player ${seat + 1}')`.
  No `TextEditingController`, so nothing to dispose and no state class.
- Footnote, last child of the scroll column: `Shown in game as “Riya · P1”.`
- The rows must not rebuild on every keystroke: select only `count` and `draft != null` (`BlocSelector`), and read the initial text once per row.

### 9.3 `lib/features/session/presentation/pages/resume_page.dart` · artboard `Resume`
State must be `ResumePrompt`, else shrink.
- The logo, card and banner below sit in `Expanded(SingleChildScrollView(…))`; the action bar and footnote are pinned.
- Centre top: `LogoMark(size: 72)` + "Spinfolk" `Tokens.numeral(36)`.
- Card (`bgSurface`, `line`, radius 24, padding 22): caption `SESSION IN PROGRESS` in `taker`; `title2` `Round R · N players`; status line (15, `textSecondary`) per D19 using `displayLabel`.
- `NoticeBanner` when `failure != null`.
- Bottom: `SizedBox(height: (64 + 10 + 50) * s, child: NativeActionBar(layout: stack, items: [resume primary 'Resume Session', end destructive 'End Session']))`; `resume` → `bloc.add(const ResumeConfirmed())`; `end` → `nav.confirmEnd()` (D8). Footnote: `Ending clears players and rounds. Voice settings stay.`

### 9.4 `lib/features/game/presentation/pages/game_page.dart` · artboards `Ready`, `Spinning`, `Revealed`, `Challenge`, `Crowd60`
If the state is not `SessionActive` → empty `Scaffold` (this is what sits under the End dialog when it is opened from Resume).

`Column`:
1. **Top bar** (top padding 8): `Row` with
   - `Flexible` pill: min height 44, capsule, `bgRaised` + `line`, horizontal padding 16, one `Text.rich` on one line with ellipsis — `Round R` (15 / w600 / `textPrimary`) + ` · ` + `N players` (15 / `textSecondary`). One Semantics node reading `Round R · N players`. Not a button.
   - `Spacer`, then a 44-pt circular button (`bgRaised` + `line`), three 4-pt dots drawn with plain `Container`s (no icon font), `Semantics(button: true, label: 'Session and settings')`, tap → `nav.settings()`.
2. **Stage** — `Expanded(LayoutBuilder)`: `f` = 0.70 (ready, spinning), 0.56 (revealed), 0.44 (challenge); `dial = min(constraints.maxWidth, constraints.maxHeight * f).clamp(120.0, 350.0)`.
   `Column[ AnimatedContainer(duration: reduce ? Duration.zero : Tokens.panelEnter, width: dial, height: dial, child: const SpinStage()), Expanded(SingleChildScrollView(child: AnimatedSwitcher(duration: reduce ? Duration.zero : Tokens.panelEnter, child: <panel keyed by phase/spinning>))) ]`.
   `SpinStage` must stay the same element across phases (do not key it by phase) so the controllers survive.
   - Top of the panel in every phase: `NoticeBanner(failure.message)` when `failure != null`.
   - Ready panel: card (`bgSurface`, `line`, radius 20, padding 18) with two legend rows — a 10-pt `taker` square + `Neck picks who takes the challenge` (bold "Neck"); a 10-pt `giver` square + `Base points to who gives it` (bold "Base").
   - Spinning panel: min-height-94 box, radius 20, 1-px `line` border, centred `Waiting for the bottle…` (15, `textTertiary`). A solid border is acceptable in place of the dashed one.
   - Revealed panel: `RoleCards(session)`; then the announcement line (14 / 19, `textSecondary`): `“${speechLine(session)}”` in curly quotes. **No speaker icon and no Replay button in Phase 2.**
   - Challenge panel: card (`bgSurface`, `line`, radius 28, padding 24, gap 14): caption `ROUND R · TRUTH` (or `DARE`) in `textTertiary`; `Truth` / `Dare` in `Tokens.numeral(40)`; a `Text.rich` (19 / 26): giver label bold in `giver` color + ` asks ` + taker label bold in `taker` color + ` a question, out loud.` — for Dare: giver + ` gives ` + taker + ` a dare, out loud.`; then 14 / `textTertiary`: `The app doesn’t write challenges. The group does.` Below the card the line `“${speechLine(session)}”`. Labels come from `displayLabel`.
3. **Bottom area** — fixed height `(64 + 10 + 50) * s`, bottom padding 8, content bottom-aligned, so the dial does not move when the phase changes:
   - Row A, height `64 * s`: `Row[ if challenge: SizedBox(width: Tokens.passWidth, child: passBar), if challenge: 10 gap, Expanded(key: const ValueKey('main'), child: mainBar) ]`.
   - Gap 10.
   - Row B, height `50 * s`.

   | Phase | `mainBar` | Row B |
   |---|---|---|
   | ready | `stack` `[spin primary 'Spin']` | empty |
   | spinning | `stack` `[spin primary 'Spinning…' enabled: false]` | centred text `Result is already locked in. Leaving the app won’t change it.` |
   | revealed | `row` `[truth choice 'Truth', dare choice 'Dare']` | `Row[ Expanded(Text('Anyone can pass. No penalty.')), SizedBox(width: Tokens.passWidth, child: passBar) ]` |
   | challenge | `row` `[next primary 'Next Round']`, with `passBar` to its left in Row A | empty |

   `passBar` = `NativeActionBar(items: [pass secondary 'Pass'])`. Row-B texts: `Tokens.footnote`, `maxLines: 2`, ellipsis, `textScaler: besideIsland(context)`.
   Because `mainBar` keeps its key and position, Ready → Spinning → Revealed are config updates of one native view (as proven in Phase 1), not recreations.
   - Tap mapping (one function, a `switch` on the id): `spin` → `SpinRequested`; `truth` → `ModeChosen(Mode.truth)`; `dare` → `ModeChosen(Mode.dare)`; `pass` → `Passed`; `next` → `NextRoundRequested`. Nothing else happens in the callback.

### 9.5 `lib/features/settings/presentation/pages/settings_sheet_page.dart` · artboard `Settings` (Phase 2 form, D10)
The route supplies scrim, slide and barrier dismissal. The page is:
`Align(bottomCenter)` → `ConstrainedBox(maxHeight: screen height − 54, maxWidth: Tokens.maxContentWidth)` → `Material(color: Tokens.bgSheet, shape: top corners radius 34 with a 1-px `line` top border)` → `SafeArea(top: false)` → `SingleChildScrollView` → `Column(mainAxisSize: min)`, padding 10 / 16 / 16:
1. Grabber 40 × 5, radius 3, `line`, centred.
2. Row: `Session` (`title2`) · `TextButton` `Done` → `nav.game()`.
3. Section label `PLAYERS` (13 / w600 / 0.6 tracking / `textTertiary`, inset 16). Card (`bgSurface`, `line`, radius 18):
   - Summary row, min height 50, not tappable: `N players · K named`, or `N players` when K = 0.
   - Divider `line`.
   - Row `Edit Players` with a trailing `›` in `textTertiary`, min height 50. Enabled only when phase is `ready` and not spinning: tap → `setup.seed(session.playerCount, [for p in players: p.name]); nav.setup(editing: true);`. Otherwise text in `textTertiary`, no tap handler, `Semantics(enabled: false)`.
   - Footnote under the card: `Editing between rounds keeps the session; current round resets.`
4. Section label `SESSION`. Card with one row `End Session` in `giver` color, min height 50 → `nav.confirmEnd()`. While spinning: dimmed, no handler.

**Not present in Phase 2:** the VOICE section (Announcements, Voice, Speed, Preview, "Only voices already on this iPhone…") and the Live Activity status line. Do not render them disabled. Do not create `settings/domain`, `settings/data` or `settings_cubit.dart`.

If the state is not `SessionActive` → `SizedBox.shrink()`.

### 9.6 `lib/features/game/presentation/pages/end_confirm_page.dart` · artboard `EndConfirm`
Reads the session from `SessionActive` **or** `ResumePrompt`; any other state → shrink.
`Align(bottomCenter)` → `SafeArea` → `Padding(8)` → `ConstrainedBox(maxWidth: Tokens.maxContentWidth)` → `Column(mainAxisSize: min, gap 8)`, where items 1–2 are wrapped together in `Flexible(SingleChildScrollView(…))` and the action bar is pinned:
1. Text card: `Material(color: Tokens.bgRaised, radius 24, 1-px line border)`, padding 18 × 20, centred: `End this session?` (15 / w600) and (13 / 18, `textSecondary`) `Clears N players and R rounds. Voice settings stay. Lock Screen activity ends too.` — `R = session.round`; write `1 round` / `1 player` forms correctly (N is never 1). `Semantics(namesRoute: true)` on the card.
2. `NoticeBanner` when `failure != null`.
3. `SizedBox(height: (50 + 10 + 50) * s, child: NativeActionBar(layout: stack, items: [end destructive 'End Session', cancel secondary 'Cancel']))`; `end` → `bloc.add(const EndConfirmed())` (the redirect then leaves the page); `cancel` → `nav.game()`.

---

## 10. Cleanup and rules

```sh
git rm -r --cached lib/dev tool/phase1_proof.yaml 2>/dev/null; rm -rf lib/dev tool/phase1_proof.yaml
```
- `tool/check_rules.sh`: delete the line `-e '^lib/dev/proof_spin.dart$' \` (keep the `spin_stage.dart` line; fix the trailing backslash). Add one rule before the final echo:
  ```sh
  pres=$(find lib/features -type d -name presentation 2>/dev/null)
  [ -n "$pres" ] && src "^import .*/data/" $pres && bad 'presentation must not import data'
  ```
- `lib/app/router.dart`: no `TEMP(phase-1)` text and no `dev/` import remain.
- Self-test the script once, then undo: add `import '../../data/session_db.dart';` to a page → exit 1; remove → exit 0.
- `grep -rn "TEMP(phase-1)\|lib/dev\|GlassProofPage\|ProofCubit" lib test tool` prints nothing.

---

## 11. Widget tests

### `test/support/harness.dart`
```dart
/// Registers a SessionBloc on a fake repository, the real router and navigator,
/// then pumps SpinfolkApp. Returns the fake.
Future<FakeSessionRepository> pumpApp(
  WidgetTester tester, {
  Session? stored,
  int seed = 1,
  Size size = const Size(390, 844),
  double textScale = 1,
});
void tapBar(WidgetTester tester, String id);   // finds the NativeActionBar holding an enabled item `id` and calls onTap(id)
```
- `pumpApp`: `tester.view.devicePixelRatio = 1; tester.view.physicalSize = size; tester.platformDispatcher.textScaleFactorTestValue = textScale;` with `addTearDown` resets; `await getIt.reset()`; register `SessionBloc(repo, Random(seed))` (singleton), `GoRouter` via `buildRouter(bloc)`, `AppNavigator`, `SetupCubit` (factory); `bloc.add(const AppStarted()); await tester.pump();` then `pumpWidget(const SpinfolkApp()); await tester.pumpAndSettle();`. `addTearDown` closes the bloc and resets `getIt`.
- On the test host the islands are empty boxes, so buttons are driven with `tapBar`. `expect` fails if no enabled item with that id exists.
- Do not call `configureDependencies()` in tests (it opens the real database).

### `test/app_smoke_test.dart` (rewrite)
`pumpApp` with nothing stored → `find.text('New Game')`. With a stored session → `find.text('SESSION IN PROGRESS')`.

### `test/game_flow_test.dart`
For each n in {2, 3, 5, 7, 59, 60}: `pumpApp`; set the count with `tester.element(find.byType(NewGamePage)).read<SetupCubit>().countChanged(n)`; `tapBar('start')` → pill text `Round 1 · n players` found; `tapBar('spin')`; `pump()` → `Waiting for the bottle…` and no `TAKER` text; `pumpAndSettle(const Duration(milliseconds: 100))` (spin ≤ 5.4 s + pulse) → `find.bySemanticsLabel(RegExp('^Taker .*, Giver .*'))`; `tapBar('truth')` → text containing `a question, out loud.`; `tapBar('next')` → `Round 2`; spin, settle, `tapBar('pass')` → `Round 3`; spin, settle, `tapBar('dare')`, `tapBar('pass')` → `Round 4`; after every step `repo.stored!.isValid`. Then settings: tap the `Session and settings` semantics node → `Edit Players` found; tap `End Session` → `End this session?`; `tapBar('end')` → `New Game` and `repo.stored == null`.
Extra cases: End from Resume (stored session → `tapBar('end')` → dialog → `tapBar('cancel')` → back on Resume; again → `tapBar('end')` twice → New Game); Edit Players (ready → sheet → `Edit Players` → `Edit Players` title → `countChanged(5)` → `tapBar('save')` → `Round 1 · 5 players`); `Edit Players` row inert in `revealed`; names flow (Add Names → enter text in the first field → Done → `Edit Names · 1 named`; Cancel discards); storage failure on spin shows the banner text `Couldn't save. Try again.` and the `Spin` item is enabled again; after End, New Game shows no names (`Add Names` link text is back).

### `test/layout_test.dart`
Sizes × scales: `Size(375, 667)` with text scales 1.0, 1.35, 3.12, and `Size(320, 568)` with 1.0. For each, visit: New Game; Add Names (count 60); Resume (stored, challenge phase, named players); Game ready; spinning (`pump(const Duration(milliseconds: 200))`); revealed and challenge with 60 players where **both** roles have 40-character names (store a prepared `Session` and resume it rather than relying on chance); revealed with unnamed players (side-by-side cards); Session sheet; End confirmation; New Game in edit mode. After each `pumpAndSettle`, `expect(tester.takeException(), isNull)`. A `RenderFlex` overflow is reported as an exception by `flutter_test`, so this is the automated half of the "SE-size + largest text" gate.

---

## 12. Verify

### 12.1 Static (paste the output of each)
```sh
fvm dart run build_runner build --delete-conflicting-outputs
fvm dart format --set-exit-if-changed .
fvm flutter analyze
fvm flutter test
tool/check_rules.sh
git diff --stat pubspec.yaml ios/        # pubspec: assets + fonts only; ios: Info.plist orientation only
grep -rnE "extends StatefulWidget" lib/  # exactly one hit: spin_stage.dart
grep -rnE "\.push\(|Navigator\.of|getIt<" lib/features lib/platform   # no hits
```
Order stays codegen → format → analyze. If `dart format` flags the generated config, run `fvm dart format .` after codegen.

### 12.2 Maestro flows — create `tool/maestro/`

`tool/maestro/loop.yaml`
```yaml
appId: in.appamania.spinfolk
env:
  N: "8"
---
- launchApp
- assertVisible: "New Game"
- tapOn: "Start Session"
- assertVisible: "Round 1 · ${N} players"
- assertVisible: "Dial, ${N} players, ready to spin"
- tapOn: "Spin"
- assertVisible: "Spinning…"
- extendedWaitUntil: { visible: "Taker .*", timeout: 15000 }
- takeScreenshot: docs/plans/phase-2/evidence/p2-loop-n${N}-revealed
- tapOn: "Truth"
- assertVisible: ".*a question, out loud\\."
- tapOn: "Next Round"
- assertVisible: "Round 2 · ${N} players"
- tapOn: "Spin"
- extendedWaitUntil: { visible: "Taker .*", timeout: 15000 }
- tapOn: "Pass"
- assertVisible: "Round 3 · ${N} players"
- tapOn: "Spin"
- extendedWaitUntil: { visible: "Taker .*", timeout: 15000 }
- tapOn: "Dare"
- assertVisible: ".*a dare, out loud\\."
- tapOn: "Pass"
- assertVisible: "Round 4 · ${N} players"
- stopApp
- launchApp
- assertVisible: "Resume Session"
- assertVisible: "Round 4 · ${N} players"
- tapOn: "Resume Session"
- assertVisible: "Dial, ${N} players, ready to spin"
- tapOn: "Session and settings"
- assertVisible: "Edit Players"
- takeScreenshot: docs/plans/phase-2/evidence/p2-loop-n${N}-sheet
- tapOn: "End Session"
- assertVisible: "End this session?"
- tapOn: "End Session"
- assertVisible: "New Game"
```

`tool/maestro/edit.yaml` — default build (count 8): Start Session → `Session and settings` → `Edit Players` → assert `Edit Players` (title) → swipe the wheel (reuse the coordinates that worked in `tool/phase1_proof.yaml` before deleting it) → `Save Players` → `assertNotVisible: "Round 1 · 8 players"` and `assertVisible: "Round 1 · .* players"` → screenshot `p2-edit`. This also re-proves wheel → cubit in the real screen.

`tool/maestro/screens.yaml` — for the SE run, built with `SPINFOLK_INITIAL_COUNT=2`, env `TAG`: screenshot New Game → `tapOn: "Add Names.*"` → type a 40-character name into both rows (tap the row by its hint text `Player 1` / `Player 2`; fall back to `point:` coordinates if the hint is not matched) → screenshot Names → `Done` → `Start Session` → screenshot Ready → `Spin` → wait `Taker .*` → screenshot Revealed → `Truth` → screenshot Challenge → `Session and settings` → screenshot Sheet → `End Session` → screenshot End dialog → `Cancel`. Screenshot names `p2-se-${TAG}-<screen>`. With two players both roles are always named, so the long-name layout is guaranteed.

Maestro matches the whole element text as a regular expression, so `"Spin"` does not match `"Spinning…"`, and parentheses must be avoided or escaped.

`tool/phase2_gate.sh` (`chmod +x`):
```sh
#!/usr/bin/env bash
# Phase 2 simulator gate: fresh install + full Maestro loop per player count.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SIM:?set SIM to a booted simulator UDID}"
APP=in.appamania.spinfolk
mkdir -p docs/plans/phase-2/evidence
for n in ${COUNTS:-2 3 5 7 59 60}; do
  fvm flutter build ios --simulator --debug --dart-define=SPINFOLK_INITIAL_COUNT="$n"
  xcrun simctl uninstall "$SIM" "$APP" || true
  xcrun simctl install "$SIM" build/ios/iphonesimulator/Runner.app
  ~/.maestro/bin/maestro --device "$SIM" test -e N="$n" tool/maestro/loop.yaml
done
```

### 12.3 Simulator gate (P2-12 … P2-17)
```sh
mkdir -p "$EVID"
xcrun simctl boot "$SIM" 2>/dev/null; xcrun simctl bootstatus "$SIM" -b; open -a Simulator

# First launch on device: proves sqflite over SwiftPM opens the database.
fvm flutter build ios --simulator --debug
xcrun simctl uninstall "$SIM" "$APP" || true
xcrun simctl install "$SIM" build/ios/iphonesimulator/Runner.app
xcrun simctl launch --console-pty "$SIM" "$APP"     # watch for exceptions, then Ctrl-C
xcrun simctl io "$SIM" screenshot "$EVID/p2-01-new-game.png"

# P2-12 / P2-13
SIM="$SIM" tool/phase2_gate.sh 2>&1 | tee "$EVID/p2-gate.log"

# P2-16 (default build again)
fvm flutter build ios --simulator --debug
xcrun simctl uninstall "$SIM" "$APP"; xcrun simctl install "$SIM" build/ios/iphonesimulator/Runner.app
~/.maestro/bin/maestro --device "$SIM" test tool/maestro/edit.yaml
```
Open every `p2-loop-n*-revealed.png` with the Read tool and state, per N, what is actually visible: disc or tick mode, where the teal neck points, whether the dotted coral arc is present (required for 3, 5, 7, 59; absent for 2 and 60), whether the numerals look ExtraBold (compare with the artboard; a thin face means the `wght` variation is not applied). The `-sheet` screenshots cover P2-17: the scrim must cover the game's native bar cleanly.

SE size and text sizes (P2-14):
```sh
SE=$(xcrun simctl create "Spinfolk SE3" com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation com.apple.CoreSimulator.SimRuntime.iOS-26-5)
xcrun simctl boot "$SE"; xcrun simctl bootstatus "$SE" -b
fvm flutter build ios --simulator --debug --dart-define=SPINFOLK_INITIAL_COUNT=2
for size in large extra-extra-extra-large accessibility-extra-extra-extra-large; do
  xcrun simctl ui "$SE" content_size "$size"
  xcrun simctl uninstall "$SE" "$APP" || true
  xcrun simctl install "$SE" build/ios/iphonesimulator/Runner.app
  ~/.maestro/bin/maestro --device "$SE" test -e TAG="$size" tool/maestro/screens.yaml
done
# 60 players at the largest size, tick mode on the small screen
xcrun simctl uninstall "$SE" "$APP"
SIM="$SE" COUNTS=60 tool/phase2_gate.sh
xcrun simctl ui "$SE" content_size large
xcrun simctl shutdown "$SE"      # keep the device for Phase 3; do not delete it
```
Open every `p2-se-*` screenshot. Pass = nothing clipped, overlapping or striped; native button labels fully inside their capsules; scrollable regions scroll instead of overflowing. If a native label is clipped at the accessibility size, raise the upper clamp in `barScale` (not the Swift code) and re-run. If Maestro cannot find an element only at the largest size (it scrolled off-screen), add `scrollUntilVisible` to the flow rather than shrinking text.

Reduce Motion (P2-15), same keys as Phase 1:
```sh
xcrun simctl spawn "$SIM" defaults write com.apple.Accessibility ReduceMotionEnabled -bool YES
xcrun simctl terminate "$SIM" "$APP"; xcrun simctl launch "$SIM" "$APP"
# Start Session, tap Spin (Maestro or by hand); the reveal must appear within about 1 s.
xcrun simctl io "$SIM" screenshot "$EVID/p2-reduce-motion.png"
xcrun simctl spawn "$SIM" defaults write com.apple.Accessibility ReduceMotionEnabled -bool NO
```
In `loop.yaml` terms: with Reduce Motion on, replace the 15 000 ms wait by 2000 ms for this one run; it must still pass.

Finish:
```sh
fvm flutter build ios --simulator --debug        # leave a default-count build installed
tool/check_rules.sh                              # P2-18
git status --short
```

If Maestro cannot drive this simulator, mark P2-12 … P2-17 **NOT VERIFIED**, keep the widget-level results (P2-10, P2-11), and give the owner the loop as a numbered manual script with the expected text after each step.

Trouble guide:
- App hangs on the launch screen: `main()` is waiting for the first state — `load()` threw something that is not a `Failure`. Run with `--console-pty` and read the log; the bloc must turn every load error into `NoSession`.
- `DatabaseException … CHECK constraint failed` during play: a handler wrote a state the schema forbids; fix the handler, never the schema.
- Blank island after a phase change: the island was recreated; check that `mainBar` kept its `ValueKey('main')` and its place in Row A.
- Redirect loop error from go_router: `sessionRedirect` returned a location that it itself rejects; the unit test table in §6 must cover that cell.

**Suggested commits:** `Phase 2: session domain, rules and SQLite repository` (after step 3) · `Phase 2: SessionBloc and routing` (after step 6) · `Phase 2: dial, spin stage and screens; remove Phase 1 harness` (after step 11).

## 13. Report format

1. What works.
2. Each acceptance check P2-1 … P2-18: PASS / FAIL / NOT VERIFIED, with the real command output or the screenshot path and one line describing what the image shows.
3. Font checksums; anything in the Phase 0–1 code that differed from what this file assumes; the final `barScale` clamp if it was changed.
4. Deviations from this file, with the reason. Deviations from the artboards beyond D9, D10, D19.
5. Open questions from `prd.md` §10 that the owner has not answered, restated in one line each.
6. Next step (Phase 3): prefs + `SettingsCubit` + Voice section, native speech on `spinfolk/native`, `Announcer` on `replayCount` and live reveal, Replay button, `AppLifecycleListener` → `AppBackgrounded`, kill/restore gate.
