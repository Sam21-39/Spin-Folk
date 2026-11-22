# Spinfolk — Phase 5 (proof, polish, release prep) + final device pass: Technical PRD

Companion: `guidelines.md` (this folder). Sources: `docs/spec-v2.md` (Part B Phase 5, README requirement, Amendments), `docs/design/project/Logo.dc.html`, every `docs/plans/phase-*/prd.md`.

## 1. Problem

Phases 0–4 are built and committed. Three things are still missing before the work can be merged and a beta attempted:

1. **Proof.** Every simulator and Maestro check since Phase 2b was deferred by owner decision. The flows exist but most have never been run against the real app. The Phase 1 and Phase 2 gates did run, but on screens that Phase 2b replaced.
2. **Release hygiene.** The app icon is still the Flutter placeholder, the launch screen is white in a dark-only app, the README describes a project that "has not been implemented", and nobody has built the release configuration or audited the bundle.
3. **Hand-off.** Six phase branches must land on `main` through `dev`, and TestFlight is blocked on one fact only the owner has (the Apple team ID).

## 2. Verified facts (checked 2026-11-22, not assumed)

| Fact | How checked |
|---|---|
| `phase-4` head is `7124625` "Phase 4: Live Activity and Dynamic Island", pushed, tree clean. History is linear: `main` (85f7081) → `phase-0-1` → `phase-2` → `phase-2b` (2 commits) → `phase-3` → `phase-4`. | `git log`, `git merge-base --is-ancestor` |
| `gh` is logged in as the repo owner; `origin` is `https://github.com/Sam21-39/Spin-Folk.git`. | `gh auth status`, `git remote -v` |
| Simulators exist: iPhone 17 Pro iOS 26.5 `2938F81B-D7F8-4DFD-81D8-968C25C04F1F`; "Spinfolk SE3" iOS 26.5 `584BBD07-5D8E-4995-A740-1155986A238E` (created in Phase 2); iPhone 16e iOS 18.6 `66C64697-4A19-4C8F-85FE-3FEE1469323D`. iPhone 16e has a notch, not a Dynamic Island. | `xcrun simctl list devices available` |
| Tools: Xcode 27.2, Maestro 2.11.0 at `~/.maestro/bin/maestro`, `fvm`, `swift`, `sips`, `sqlite3`, `gh`, `xcodeproj` gem 1.27.0. No `rsvg-convert`. | `which`, `--version` |
| `pubspec.yaml`: `version: 0.1.0+1`; direct deps `material_ui 1.11.1`, `flutter_bloc 9.1.1`, `get_it 9.3.0`, `injectable 3.0.0`, `go_router 18.1.4`, `sqflite 2.4.6`, `shared_preferences 2.5.6`, `adaptive_platform_ui 1.0.2`; dev `flutter_lints`, `injectable_generator`, `build_runner`, `sqflite_common_ffi`. No `flutter_tts`. All pinned exactly. | file read |
| `material_ui` is approved (Phase 0–1 PRD, open question 1) but is not in spec A9 or the Amendments. | spec read |
| `ios/Runner/Info.plist`: `NSSupportsLiveActivities` true, scheme `spinfolk`, `FlutterDeepLinkingEnabled` false, `UIUserInterfaceStyle` Dark, portrait on iPhone. No `UIBackgroundModes`, no `NSMicrophoneUsageDescription`. | file read |
| Project file: bundle ids `in.appamania.spinfolk` and `in.appamania.spinfolk.SpinfolkWidget`; deployment target 17.0; widget version taken from `FLUTTER_BUILD_NAME` / `FLUTTER_BUILD_NUMBER`; no `DEVELOPMENT_TEAM`; `TARGETED_DEVICE_FAMILY = "1,2"` on both targets; SwiftPM only (no Podfile, no entitlements file). | `grep` on `project.pbxproj`, `find ios` |
| SwiftPM is switched on by the machine-global Flutter setting `enable-swift-package-manager: true`, not by anything in the repo. | `fvm flutter config --list` |
| App icon: 15 Flutter placeholder PNGs in `ios/Runner/Assets.xcassets/AppIcon.appiconset`. The widget target has no asset catalog. | `ls`, `Contents.json` |
| `ios/Runner/Base.lproj/LaunchScreen.storyboard` background is white (`red="1" green="1" blue="1"`); `LaunchImage` is a 1 px transparent PNG. `lib/main.dart` relies on the launch screen to cover the database open. | file read, `sips` |
| Logo geometry (`Logo.dc.html`, viewBox 100): eight dots on radius 36 from twelve o'clock; dot 1 (45°) teal `#2DD4BF` r 6.2; dot 5 (225°) coral `#FF7A59` r 6.2; others `#3A4D74` r 4.6; bottle = `translate(50 50) rotate(45) scale(0.27)` of the body path (`#E8EEF7` at 0.95), lip rect `-10,-100 20×12 rx 4` teal, base rect `-22,70 44×14 rx 6` coral; ground `#0B1424`. The same numbers are in `lib/app/logo_mark.dart`. | file read |
| A 45-line Swift/CoreGraphics script renders that geometry to an opaque 1024 px sRGB PNG in under one second on this Mac, and the result matches the artboard. | prototype run outside the repo, image inspected |
| The repo holds no certificate, profile, key, token, team ID or device UDID; `.gitignore` already lists `*.mobileprovision *.p12 *.cer *.p8` and `docs/plans/*/evidence/`. Simulator UUIDs appear in `docs/plans/*/guidelines.md`; they are machine-local simulator ids, not device UDIDs. | `git grep`, `git ls-files` |
| Runner's own Swift uses no required-reason API (`UserDefaults`, file timestamps, boot time, disk space). | `grep` |
| UI strings used by the Maestro flows all exist in `lib/` as written ("New game", "Start session", "Resume game", "Session and settings", "Edit Players", "Save Players", "End Session", "End this session?", "Good game.", "Next Round", "Spinning…", "Replay announcement", "Announcements", "Play sample", "No past games yet", "Game deleted", "ROUND LOG", "Lock Screen updates are off in iOS Settings."). Name fields carry the semantics label `Name for player N`. | `grep` |
| `tool/maestro/phase4.yaml` cannot run as written: the "start a game" steps are a comment placeholder. `tool/maestro/screens.yaml` needs `Y1`/`Y2` tap coordinates nobody has measured. | file read |
| Phase 1 and Phase 2 gate evidence exists locally (git-ignored) under `docs/plans/phase-0-1/evidence/` and `docs/plans/phase-2/evidence/`. | `ls` |

Not checked here (no build was run while Phase 4 was being finished): whether `fvm flutter build ios --release --no-codesign` succeeds with the widget target. It is the first release-prep step.

## 3. Scope

### In
1. **Static proof**: `fvm dart format --set-exit-if-changed .`, `fvm flutter analyze`, `fvm flutter test`, `tool/check_rules.sh`.
2. **App icon** from the canvas geometry: `tool/make_icon.swift` → one 1024 px PNG in the Runner asset catalog.
3. **Launch screen** background set to `#0B1424`.
4. **Audit**, with fixes only where the audit finds a mismatch: Info.plist against behaviour, dependency list against spec + amendments, release build, both bundle ids, version 0.1.0 (1), icon present, no secrets, `.gitignore`.
5. **`tool/final_gate.sh`**: one runnable script that drives every deferred simulator check on the three simulators. Existing Maestro flows are repaired and reused; three small flows are added.
6. **One run of that gate**, with every screenshot reviewed and a PASS / FAIL / NOT VERIFIED line per deferred item.
7. **Owner checklist**: the checks that cannot be automated.
8. **README** rewritten per spec, short.
9. **Spec amendment**: one Phase 5 block recording `material_ui`.
10. **Cleanup**: delete `tool/phase2_gate.sh`, `tool/phase3_gate.sh`, `tool/phase4_gate.sh`.
11. **Branch flow commands** for the coordinator (`dev` from `main`, six merges, PR `dev` → `main`).

### Out
- TestFlight, archive, device build, signing of any kind. Blocked on the team ID (§9, question 1).
- New features, new dependencies, refactors, visual redesign.
- Fixing an app defect found by the gate without reporting it first (§5 D8).

## 4. Non-goals

- No `DEVELOPMENT_TEAM`, entitlements file, export-options plist, provisioning profile or API key in the repo, now or after the team ID is known.
- No CocoaPods, no fastlane, no CI workflow.
- No dark / tinted / light icon variants. iOS derives them from the single icon; the artboard's "light" and "tinted" tiles are not built (§9, question 5).
- No widget-extension icon or asset catalog: a Live Activity shows the host app's icon.
- No real-device measurements (jank, audio, haptics). They need the team ID.
- No evidence in git. Screenshots and logs stay under the git-ignored `docs/plans/*/evidence/`.
- No rewrite of earlier phase plans.

## 5. Key decisions

**D1. Icon generator.** Problem: a 1024 px PNG from vector geometry with no new pub dependency. Options: (a) Dart, rendering `LogoMark` to an image inside `flutter test`; (b) Swift + CoreGraphics script; (c) convert an SVG with `qlmanage` or `sips`. Pick **(b)**: runs with the toolchain every iOS developer has, needs no test-binding tricks, controls the alpha channel exactly, and is already proven on this Mac. (a) would reuse the Dart painter but writes files from a test; (c) cannot guarantee an opaque square.

**D2. Icon catalog shape.** Options: keep the 15-file `Contents.json` and resize with `sips`; switch to Xcode's single-size format (one universal 1024 px entry). Pick **single-size**: one file, one source, and it is what Xcode itself creates since version 14. Fallback if `actool` or Flutter rejects it: restore `Contents.json` from git and fill the 15 sizes with a `sips -z` loop.

**D3. Icon is full-bleed and opaque.** The artboard draws rounded corners; iOS applies its own mask and App Store Connect rejects alpha. The script fills the whole square with `#0B1424`.

**D4. Launch screen.** Options: leave white; navy background; add a logo image. Pick **navy background only**: one attribute in the storyboard removes a white flash before a dark app. A logo image is polish nobody asked for.

**D5. One gate script, stages inside.** Options: keep three per-phase scripts and add a wrapper; one script with named stages. Pick **one script** (`tool/final_gate.sh [stage…]`), because the per-phase scripts share the same six helper lines and two of them were never run. The three old scripts are deleted; their logic moves into stages. Maestro flows stay as separate files.

**D6. A failing stage does not stop the run.** Each stage runs in a `set -e` subshell with its own log; the script prints a PASS/FAIL table and exits non-zero if any stage failed. One run then shows the whole picture.

**D7. One evidence folder.** Options: keep each flow writing to its own phase folder; send everything to `docs/plans/phase-5/evidence/`. Pick **one folder**: the reviewer opens one place. File-name prefixes (`p2b-`, `p3-`, `p4-`) keep the origin readable.

**D8. Flows are fixed, the app is not.** The flows have never met the real app, so selector and timing repairs are expected and are part of this phase. If a check fails because the *app* is wrong, the implementer stops that item, records FAIL with the screenshot, and reports it. A one-line, obviously safe fix (a missing semantics label, a wrong string) may be made with its test; anything touching state, storage, speech or ActivityKit logic goes back to the coordinator.

**D9. Simulator ids.** Options: hard-code; look up by name and runtime; environment variables with defaults. Pick **env with defaults** (`SIM`, `SE`, `SIM18`). The ids are local simulator identifiers, already present in earlier plans, and not device UDIDs.

**D10. Lock Screen capture.** `simctl` has no lock command. Options: Maestro `pressKey: Lock`; pull down Notification Center (it shows Live Activities the same way); owner by hand. Pick **Notification Center swipe first, `pressKey: Lock` second, owner checklist third**. At most two repair attempts, then NOT VERIFIED.

**D11. What "never during the spin" means on a device.** Leaving the app mid-spin completes the spin by design (Phase 3), which then syncs the activity. So the Lock Screen cannot show a mid-spin state at all. P4-D2's "never during the spin" stays proven by `live_activity_sync_test` (P4-8); the device check covers reveal, mode and next round.

**D12. Team ID never enters the repo.** When the owner supplies it, it is passed per command through Flutter's `FLUTTER_XCODE_DEVELOPMENT_TEAM` environment variable. `tool/check_rules.sh` keeps failing on any `DEVELOPMENT_TEAM` in the project file.

**D13. README.** Rewritten from scratch, about one screen. Versions are stated once (Flutter from `.fvmrc`; packages "pinned in `pubspec.yaml`"), not copied.

**D14. `CLAUDE_HANDOFF.md` stays.** It is history; the README points to `docs/spec-v2.md` as the authority. Deleting it is the owner's call (§9, question 6).

**D15. `tool/add_widget_target.rb` stays.** It is idempotent and documents how the extension target was created.

## 6. Deferred items → where each is proven

`A` = automated assertion in `final_gate.sh`; `S` = screenshot from the gate, judged by the implementer; `M` = owner checklist (§8); `T` = already proven by a unit/widget test, no device form.

| Item | Check | Stage | Kind |
|---|---|---|---|
| P1-1 | Wheel value reaches the cubit (count changes after a wheel swipe) | `edit` | A |
| P1-2 | Spin → "Spinning…" → enabled again | `loop` | A |
| P1-3 | Glass is real Liquid Glass on iOS 26, not a flat card | `loop` | S |
| P1-4 | No blocked touches: native bars, wheel and Flutter controls all respond | `loop`, `edit`, `history` | A |
| P1-5 | No jank in a spin | — | M (simulator indicative; device needs team ID) |
| P1-6 | Reduce Motion / Reduce Transparency | `motion` | A + S |
| P1-7 | iOS 18.6 fallback renders `.ultraThinMaterial`, same shapes | `ios18` | A + S |
| P1-8 | `stack` and `row` layouts, all styles | `loop` | S |
| P1-9 | Format, analyze, tests, rules | `static` | A |
| P1-10 | No retain cycles | — | T (code review done in Phase 1) |
| P2-12 | Full loop for N = 2, 3, 5, 7, 59, 60 | `loop` | A |
| P2-13 | Dial visuals per N | `loop` | S |
| P2-14 | SE size × three text sizes, no overflow | `se` | A + S |
| P2-15 | Reduce Motion: reveal in about 0.6 s | `motion` | A |
| P2-16 | Edit Players keeps the round | `edit` | A |
| P2-17 | Sheet and dialog scrim over the game | `loop`, `se` | S |
| P2b-S1 | `GlassButton` glass on 26, material on 18, labels legible, Undo white with navy text | `loop`, `history`, `ios18` | S |
| P2b-S2 | No jank with pill + settings + bar | — | M |
| P2b-S3 | VoiceOver labels, "Delete game" action, chip announcements | — | M |
| P2b-S4 | Wheel animates to chip; sheet detents and drag dismiss; no native view through a scrim | `loop` (scrim) | S + M |
| P2b-S5 | `loop.yaml`, `history.yaml` | `loop`, `history` | A |
| P3-D1 | Prefs persist across kill | `lifecycle` | A + S |
| P3-D2 | Kill mid-spin → reveal, same roles, no speech | `lifecycle` | A (speech: M) |
| P3-D3 | Background mid-spin → revealed on return | `lifecycle` | A (speech, haptic: M) |
| P3-D4 | End removes the session, keeps history and prefs | `lifecycle` | A |
| P3-D5 | Corrupt row → notice + clean Home | `lifecycle` | S |
| P3-D6 | Audio: mute switch, ducking, interruption, voices, unduck on background | — | M (real device) |
| P3-D7 | Adaptive switch/slider in the sheet; VoiceOver reads label + switch as one | `lifecycle` (responds) | S + M |
| P4-D1 | Activity starts on session start | `activity` | S |
| P4-D2 | Updates after reveal, mode, next round | `activity` | S (+ T for "never during the spin", D11) |
| P4-D3 | Lock Screen and compact layouts match the canvas; expanded and minimal | `activity` | S + M (expanded, minimal) |
| P4-D4 | Link returns to the session, warm and cold; foreign id ignored | `activity` | S |
| P4-D5 | End Session ends the activity | `activity` | S |
| P4-D6 | Relaunch: exactly one activity | `activity` | S |
| P4-D7 | Live Activities off in Settings: play unaffected, sheet line shown | — | M |
| P4-D8 | Same on hardware | — | M (team ID) |

## 7. Acceptance checks

Static and release (real output pasted in the report)
- P5-1 `tool/final_gate.sh static` → PASS (format, analyze "No issues found!", all tests, `check_rules: OK`).
- P5-2 `tool/final_gate.sh release` → PASS: `fvm flutter build ios --release --no-codesign` succeeds; app id `in.appamania.spinfolk`, extension id `in.appamania.spinfolk.SpinfolkWidget`; both `0.1.0` / `1` / minimum OS `17.0`; `NSSupportsLiveActivities` true; scheme `spinfolk`; `FlutterDeepLinkingEnabled` false; no `UIBackgroundModes`, no `NSMicrophoneUsageDescription`; `CFBundleIconName` = `AppIcon`; `Assets.car` present; no team identifier.
- P5-3 Icon: `swift tool/make_icon.swift` reproduces the committed PNG byte-for-byte or pixel-for-pixel; the PNG is 1024 × 1024, no alpha; the simulator Home Screen shows the icon (screenshot); it matches the artboard's "App icon" tile.
- P5-4 Launch screen is navy (screenshot taken within a second of a cold launch, or storyboard diff).
- P5-5 Secrets: the scan in guidelines §3.4 prints nothing; `.gitignore` holds the four signing patterns and the evidence pattern; `git status` shows no evidence file.
- P5-6 Dependencies: `pubspec.yaml` direct dependencies equal spec A9 + Amendments exactly (after the Phase 5 amendment for `material_ui`); nothing uses `^`; `pubspec.lock` committed; `git diff phase-4 -- pubspec.yaml pubspec.lock` is empty.
- P5-7 README has the nine sections the spec lists, no "not implemented" text, and every command in it was run once.
- P5-8 `tool/phase2_gate.sh`, `tool/phase3_gate.sh`, `tool/phase4_gate.sh` are gone; no file refers to them; no flow file starts with "DEFERRED".

Device pass
- P5-9 `tool/final_gate.sh` (all stages) was run once on the final code; the PASS/FAIL table and each stage log are in `docs/plans/phase-5/evidence/`.
- P5-10 Every `A` and `S` row of §6 has a verdict: PASS, FAIL (with the screenshot name and what is wrong) or NOT VERIFIED (with the reason and the attempts made). No row is left blank and none is marked PASS without its log line or screenshot.
- P5-11 Accessibility settings and text size on the simulators are back to defaults after the run (`ReduceMotionEnabled`, `EnhancedBackgroundContrastEnabled` = NO; content size `large`).
- P5-12 The owner checklist (§8) is delivered in the report, unchanged or with additions for items that fell back to manual.

Hand-off
- P5-13 The report ends with the exact team-ID question of §9 and states that nothing was signed, archived or uploaded.

## 8. Owner checklist (manual only)

Simulator, about ten minutes:
1. **VoiceOver** (Settings → Accessibility, or Accessibility Inspector): glass buttons read their Flutter labels ("Session and settings", "Done", "Undo"), not symbol names; a History row offers the "Delete game" action; player-count chips read "N players, selected"; the Announcements row reads as one element with its switch.
2. **Sheets**: the session sheet snaps to both heights and dismisses by drag; tapping a count chip animates the wheel to that value.
3. **Dynamic Island**: long-press the island for the expanded view (giver → taker, round, players); start a second Live Activity from another app, if one is available, to see the minimal mark.
4. **Live Activities off**: Settings → Spinfolk → Live Activities off; play a round; the session sheet shows "Lock Screen updates are off in iOS Settings."; play is unaffected.
5. **Smoothness**: watch three spins with the pill, settings button and action bar on screen. Debug builds on a simulator are indicative only.

Real iPhone, after the team ID exists:
6. **Audio**: the line is audible with the mute switch on; music ducks and returns; a call or Siri during a line shows "Voice unavailable. Read the roles aloud."; voices listed match iOS Settings; music unducks at once when the app goes to the background.
7. **Kill or background mid-spin**: the reveal is shown on return, with no speech and no haptic.
8. **Haptic**: one medium tap when the bottle stops.
9. **Live Activity on hardware**: start, update after reveal / mode / next, Lock Screen tap returns to the game, End Session removes it.
10. **Profile-mode spin**: no dropped frames in a ten-second look.

## 9. Open questions

Material:

1. **Apple team ID (blocks TestFlight and every real-device check).** The plan stops after the simulator pass and asks exactly this:
   > To build for a device and upload to TestFlight I need three things from you. Please do not send passwords, keys or tokens.
   > 1. Your Apple Developer **Team ID** (10 characters, developer.apple.com → Membership details).
   > 2. Confirmation that the Apple ID signed in to Xcode on this Mac belongs to that team with at least the App Manager role (Xcode → Settings → Accounts).
   > 3. Confirmation that an app record for bundle ID `in.appamania.spinfolk` exists in App Store Connect, or that you want to create it yourself first.
   
   The ID will be passed on the command line only and never written to the repo.
2. **iPad.** Both targets build for iPhone and iPad (`TARGETED_DEVICE_FAMILY = "1,2"`), but no layout was ever checked on an iPad and the spec says iPhone-first. Once a version ships on the App Store with iPad support it cannot be removed. Recommended: iPhone only (`1`) before the first upload. Default in this phase: **no change**, decision needed before TestFlight.
3. **Export compliance.** The app makes no network calls and uses no encryption. Adding `ITSAppUsesNonExemptEncryption = false` to Info.plist skips the question on every upload. It is a legal declaration, so it is the owner's to make. Default: not added.

Minor (default applies unless the owner says otherwise):

4. **Old gate scripts** are deleted, not kept (D5).
5. **Icon variants**: single dark icon only (non-goals).
6. **`CLAUDE_HANDOFF.md`** is kept (D14).
7. **SwiftPM switch**: the README tells a new machine to run `fvm flutter config --enable-swift-package-manager`. Nothing in the repo enforces it.

## 10. Risks

| Risk | Likelihood | Handling |
|---|---|---|
| Release build fails on the unsigned extension target. | Low–medium | First step of release prep. Read the Xcode error; the usual cause is a signing setting on one target. Do not add a team. Report if not solved in two attempts. |
| Single-size icon rejected by `actool` or flagged by Flutter. | Low | D2 fallback. |
| Flows written blind fail on selectors or timing. | High | Expected (D8). Repair with `maestro hierarchy`; budget of two repairs per failing step, then NOT VERIFIED. |
| Lock Screen cannot be captured by automation. | Medium | D10 ladder; ends in the owner checklist. |
| Live Activity does not appear on the simulator at all. | Low–medium | It is the first real run of the ActivityKit code. Capture `xcrun simctl spawn "$SIM" log show --last 2m --predicate 'subsystem CONTAINS "activitykit" OR process == "Runner"'`, report FAIL for P4-D1 with the log, continue with other stages. Do not patch Swift blind. |
| Accessibility defaults keys do not take effect on this runtime. | Low (worked in Phase 1) | Report NOT VERIFIED for P1-6 / P2-15; add to the owner checklist. |
| Gate leaves a simulator in a changed state (text size, Reduce Motion). | Medium | `trap` in the two stages that change settings; P5-11 checks it. |
| A long gate run exceeds a tool timeout. | Medium | Run stage by stage; the loop stage alone is six builds. |
| Prefs plist key name differs from the guess (`announce` vs `flutter.announce`). | Medium | The assertion accepts both; the sheet screenshot is the fallback proof. |
| Screenshot review by a model passes something a person would not. | Medium | The owner gets the evidence folder path and the list of `S` verdicts; anything doubtful is reported as doubtful, not PASS. |
| Phase 4 review fixes land after this plan was written. | Medium | Guidelines §0: branch from the committed `phase-4` tip and re-read the three flows and `check_rules.sh` before editing. |

## Owner decisions (2026-11-22) — do not reopen
- iPhone only: set `TARGETED_DEVICE_FAMILY = 1` on Runner and SpinfolkWidget targets (all build configs) before first upload.
- Add `ITSAppUsesNonExemptEncryption = false` to ios/Runner/Info.plist.
- Launch screen background → #0B1424.
- Other plan defaults approved (single dark icon, SwiftPM config note in README, delete superseded phase gate scripts).
- Team ID still not provided: TestFlight/device steps stop and ask (guidelines §10).
