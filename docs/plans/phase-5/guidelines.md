# Spinfolk — Phase 5 + final device pass: implementation guidelines

Read `prd.md` (this folder) first. Decision ids (D1…), the deferred-item table (§6) and check ids (P5-n) refer to it. Sources: `docs/spec-v2.md`, `docs/design/project/Logo.dc.html`, `docs/plans/phase-*/prd.md`.

## 0. Ground rules

- All earlier ground rules apply: every Flutter/Dart command through `fvm`, run from the repo root; no new dependencies; no CocoaPods; no `setState`; no `DEVELOPMENT_TEAM`, entitlements, profiles or keys anywhere in the repo.
- **Start point.** Branch `phase-5` from the committed tip of `phase-4` (at planning time `7124625`). If `git status` on `phase-4` is not clean, stop and ask the coordinator.
  ```sh
  git fetch origin && git switch phase-4 && git status --short   # must print nothing
  git switch -c phase-5
  ```
- **Re-read before editing** (Phase 4 review fixes may have changed them): `tool/check_rules.sh`, `tool/maestro/*.yaml`, `tool/phase4_gate.sh`, `ios/Runner/Info.plist`, `lib/features/settings/presentation/pages/settings_sheet_page.dart` (the Live Activity status line text).
- **No signing, no archive, no upload, no device build.** The only release command is `fvm flutter build ios --release --no-codesign`.
- **This is the phase where the simulator runs.** Everything deferred since Phase 2b is run once, here.
- **Report honestly.** Paste real output. A check that was not run, or whose screenshot is ambiguous, is **NOT VERIFIED** with the reason. Never mark a screenshot check PASS without having opened the image.
- **Flows may be repaired; the app may not be redesigned** (D8). Budget: two repair attempts per failing flow step, then NOT VERIFIED. An app defect is reported with its screenshot, not silently patched. Allowed without asking: a wrong string or a missing semantics label, with its test. Not allowed without asking: changes to bloc, storage, speech or ActivityKit logic.
- Do not commit unless the coordinator asks. Suggested commits are at the end of §9.
- Long commands: run `tool/final_gate.sh` one stage at a time (the `loop` stage is six builds); use a background run or a 10-minute timeout per stage.

Step order: 1 static baseline → 2 icon + launch screen → 3 audit + release build → 4 flows → 5 `final_gate.sh` + cleanup → 6 run the gate, review evidence → 7 README + spec amendment → 8 final static block → 9 report. Then **stop** (§10). §11 is for the coordinator only.

---

## 1. Static baseline (before touching anything)

```sh
fvm flutter pub get
fvm dart run build_runner build --delete-conflicting-outputs
git diff --exit-code lib/core/di/injection.config.dart     # generated file is current
fvm dart format --set-exit-if-changed .
fvm flutter analyze
fvm flutter test
tool/check_rules.sh
```
All green, or stop and report: Phase 5 does not start on a red tree.

---

## 2. App icon and launch screen

### 2.1 Create `tool/make_icon.swift`

This exact script was run on this Mac during planning (under one second; output 1024 × 1024, sRGB, no alpha; visually equal to the artboard's "App icon" tile). Use it as written.

```swift
// Renders the Spinfolk app icon (docs/design/project/Logo.dc.html, "App icon")
// as an opaque 1024 px PNG. Usage: swift tool/make_icon.swift <out.png>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let px = 1024
func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
  CGColor(
    srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
    blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}
let ctx = CGContext(
  data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
  space: CGColorSpace(name: CGColorSpace.sRGB)!,
  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!  // no alpha: App Store rule

// SVG space: 100 x 100 units, y down.
ctx.translateBy(x: 0, y: CGFloat(px))
ctx.scaleBy(x: CGFloat(px) / 100, y: -CGFloat(px) / 100)
ctx.setFillColor(rgb(0x0B1424))
ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))  // full bleed; iOS masks the corners

// Ring: 8 seats on r 36 from twelve o'clock, clockwise. Seat 1 taker, seat 5 giver.
for i in 0..<8 {
  let a = CGFloat(i) * .pi / 4
  let r: CGFloat = (i == 1 || i == 5) ? 6.2 : 4.6
  ctx.setFillColor(rgb(i == 1 ? 0x2DD4BF : (i == 5 ? 0xFF7A59 : 0x3A4D74)))
  ctx.fillEllipse(in: CGRect(x: 50 + 36 * sin(a) - r, y: 50 - 36 * cos(a) - r, width: 2 * r, height: 2 * r))
}

// Bottle: same path as bottleBodyPath() in dial_painter.dart, neck at 45 degrees.
ctx.translateBy(x: 50, y: 50)
ctx.rotate(by: .pi / 4)
ctx.scaleBy(x: 0.27, y: 0.27)
let body = CGMutablePath()
body.move(to: CGPoint(x: -8, y: -88))
body.addLine(to: CGPoint(x: 8, y: -88))
body.addLine(to: CGPoint(x: 8, y: -40))
body.addCurve(to: CGPoint(x: 22, y: 0), control1: CGPoint(x: 8, y: -24), control2: CGPoint(x: 22, y: -18))
body.addLine(to: CGPoint(x: 22, y: 72))
body.addQuadCurve(to: CGPoint(x: 10, y: 84), control: CGPoint(x: 22, y: 84))
body.addLine(to: CGPoint(x: -10, y: 84))
body.addQuadCurve(to: CGPoint(x: -22, y: 72), control: CGPoint(x: -22, y: 84))
body.addLine(to: CGPoint(x: -22, y: 0))
body.addCurve(to: CGPoint(x: -8, y: -40), control1: CGPoint(x: -22, y: -18), control2: CGPoint(x: -8, y: -24))
body.closeSubpath()
ctx.addPath(body)
ctx.setFillColor(rgb(0xE8EEF7, 0.95))
ctx.fillPath()
func pill(_ r: CGRect, _ radius: CGFloat, _ hex: UInt32) {
  ctx.addPath(CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil))
  ctx.setFillColor(rgb(hex))
  ctx.fillPath()
}
pill(CGRect(x: -10, y: -100, width: 20, height: 12), 4, 0x2DD4BF)  // lip: taker
pill(CGRect(x: -22, y: 70, width: 44, height: 14), 6, 0xFF7A59)  // base: giver

guard CommandLine.arguments.count == 2 else { fatalError("usage: make_icon.swift <out.png>") }
let out = URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL
let dest = CGImageDestinationCreateWithURL(out, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("could not write PNG") }
```

### 2.2 Generate and install the icon

```sh
ICONSET=ios/Runner/Assets.xcassets/AppIcon.appiconset
git rm -q "$ICONSET"/Icon-App-*.png
swift tool/make_icon.swift "$ICONSET/AppIcon-1024.png"
sips -g pixelWidth -g pixelHeight -g hasAlpha "$ICONSET/AppIcon-1024.png"   # 1024, 1024, no
```

Replace `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json` with (D2, single-size format):

```json
{
  "images" : [
    {
      "filename" : "AppIcon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

No project-file change: `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` is already set on Runner. Do not add an asset catalog to `ios/SpinfolkWidget/` (PRD non-goals).

Open the PNG with the image reader and compare with the "App icon" 180 px tile in `docs/design/project/Logo.dc.html`: navy ground, eight dots, teal dot top-right, coral dot bottom-left, pale bottle from bottom-left to top-right with a teal lip and a coral base band.

Fallback, only if the build in §3.3 reports an icon error or Flutter warns about the icon set: `git checkout phase-4 -- "$ICONSET"`, then overwrite each listed file from the 1024 px master, for example `sips -z 120 120 master.png --out "$ICONSET/Icon-App-60x60@2x.png"` (pixel size = points × scale for every entry of the old `Contents.json`; the 1024 entry is a plain copy). Report that the fallback was used.

### 2.3 Launch screen — `ios/Runner/Base.lproj/LaunchScreen.storyboard`

One line. Replace
```xml
<color key="backgroundColor" red="1" green="1" blue="1" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>
```
with (`#0B1424`)
```xml
<color key="backgroundColor" red="0.0431" green="0.0784" blue="0.1412" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>
```
Leave the `LaunchImage` image view and its 1 px images alone.

Verify (simulator build, also needed later):
```sh
fvm flutter build ios --simulator --debug
SIM=2938F81B-D7F8-4DFD-81D8-968C25C04F1F
xcrun simctl boot "$SIM" 2>/dev/null; xcrun simctl bootstatus "$SIM" -b
xcrun simctl uninstall "$SIM" in.appamania.spinfolk; xcrun simctl install "$SIM" build/ios/iphonesimulator/Runner.app
mkdir -p docs/plans/phase-5/evidence
xcrun simctl launch "$SIM" in.appamania.spinfolk & xcrun simctl io "$SIM" screenshot docs/plans/phase-5/evidence/p5-launch.png   # navy or Home, never white
xcrun simctl terminate "$SIM" in.appamania.spinfolk
sleep 2; xcrun simctl io "$SIM" screenshot docs/plans/phase-5/evidence/p5-home-icon.png
```
If the Home Screen screenshot does not show the app's page, swipe to it with a three-line Maestro flow or note it for the owner; the release-bundle check in §3.3 is the binding proof that the icon is compiled in.

---

## 3. Audit

Record one line per item in the report: what was checked, the command, the result. Fix only real mismatches.

### 3.1 Info.plist against behaviour

| Key / fact | Expected | Check |
|---|---|---|
| `NSSupportsLiveActivities` | `true` | `/usr/libexec/PlistBuddy -c 'Print :NSSupportsLiveActivities' ios/Runner/Info.plist` |
| URL scheme | `spinfolk` | `…-c 'Print :CFBundleURLTypes:0:CFBundleURLSchemes:0'` |
| `FlutterDeepLinkingEnabled` | `false` | same tool |
| `UIUserInterfaceStyle` | `Dark` | same tool |
| iPhone orientations | portrait only | same tool |
| `UIBackgroundModes`, `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` | absent | `grep -cE 'UIBackgroundModes\|NSMicrophoneUsageDescription\|NSSpeechRecognitionUsageDescription' ios/Runner/Info.plist` → 0 |
| Any other `NS…UsageDescription` | absent (the app asks for no permission) | `grep -c 'UsageDescription' ios/Runner/Info.plist` → 0 |
| Entitlements files, App Groups, Podfile | none | `find ios -name '*.entitlements' -o -name Podfile` → nothing |
| Widget `Info.plist` | only `NSExtensionPointIdentifier = com.apple.widgetkit-extension` | read `ios/SpinfolkWidget/Info.plist` |
| Speech audio session | `.playback` + `.mixWithOthers` + `.duckOthers`, activated only while speaking | read `ios/Runner/Native/SpeechBridge.swift`; no code change |
| Required-reason APIs in Runner Swift | none, so no app-level `PrivacyInfo.xcprivacy` | `grep -rnE 'UserDefaults\|creationDate\|modificationDate\|systemUptime\|volumeAvailable' ios/Runner ios/SpinfolkWidget --include='*.swift'` → nothing |

Do **not** change `TARGETED_DEVICE_FAMILY` and do **not** add `ITSAppUsesNonExemptEncryption` (PRD §9, questions 2 and 3). Report both as open.

### 3.2 Dependencies against spec + amendments

```sh
sed -n '/^dependencies:/,/^flutter:/p' pubspec.yaml
grep -n '\^' pubspec.yaml                       # only the environment.sdk line
git diff phase-4 -- pubspec.yaml pubspec.lock   # empty
grep -c flutter_tts pubspec.yaml pubspec.lock   # 0 and 0
```
Expected runtime set: `material_ui`, `flutter_bloc`, `get_it`, `injectable`, `go_router`, `sqflite`, `shared_preferences`, `adaptive_platform_ui`. Dev set: `flutter_lints`, `injectable_generator`, `build_runner`, `sqflite_common_ffi`. The spec's "deliberately not added" list (`equatable`, `bloc_concurrency`, `bloc_test`, `mocktail`, `freezed`, `path`, live-activities packages) must not appear as direct dependencies. `material_ui` is covered by the amendment in §7.2.

### 3.3 Release build and bundle

Run through the gate once it exists (§5): `tool/final_gate.sh release`. Until then, by hand:
```sh
fvm flutter build ios --release --no-codesign 2>&1 | tee docs/plans/phase-5/evidence/release-build.log
```
If it fails: read the first Xcode error. A signing error on `SpinfolkWidget` means a setting asks for a team; do not add one. Two attempts, then stop and report with the log. Also note any Flutter warning about the app icon or launch image in the output.

Plugin privacy manifests (informational line for the report):
```sh
find build/ios/iphoneos/Runner.app -name 'PrivacyInfo.xcprivacy'
```

### 3.4 No secrets

```sh
git ls-files | grep -iE '\.(mobileprovision|p12|cer|p8|pem|key|keystore|jks|env)$|ExportOptions|fastlane|AuthKey'
git grep -nIiE 'DEVELOPMENT_TEAM *= *[A-Z0-9]{10}|DevelopmentTeam *= *[A-Z0-9]{10}|PROVISIONING_PROFILE|BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|issuer[_-]?id' -- . ':!docs' ':!tool/check_rules.sh' ':!tool/add_widget_target.rb'
git grep -nIE '\b[0-9a-f]{40}\b|\b0000[0-9A-F]{4}-[0-9A-F]{16}\b' -- . ':!pubspec.lock' ':!docs/design'      # device UDID shapes
git log --all --diff-filter=A --name-only --format= | grep -iE '\.(mobileprovision|p12|cer|p8)$'               # never in history either
grep -nE 'mobileprovision|\.p12|\.cer|\.p8|evidence' .gitignore                                                # five lines
git status --short docs/plans                                                                                  # no evidence file listed
```
Every command except the `.gitignore` one must print nothing. Simulator UUIDs in `docs/plans/*/guidelines.md` and in `tool/final_gate.sh` are expected (D9): they do not match the device-UDID patterns above.

---

## 4. Maestro flows

All flows live in `tool/maestro/`, are run from the repo root, and write screenshots to `docs/plans/phase-5/evidence/` (git-ignored). Maestro matches the whole element text as a regular expression: `"Spin"` does not match `"Spinning…"`; escape or avoid parentheses.

First, in the five existing files (`loop`, `edit`, `history`, `screens`, `phase3`) and `phase4`: delete the leading `# DEFERRED…` comment line(s) and point every screenshot at the one evidence folder:

```sh
sed -i '' -E '/^# DEFERRED/d; s#docs/plans/phase-[0-9a-z-]+/evidence/#docs/plans/phase-5/evidence/#' tool/maestro/*.yaml
grep -n 'evidence/' tool/maestro/*.yaml      # every hit is docs/plans/phase-5/evidence/
```

Then make the edits below. When a step fails, look before guessing: `~/.maestro/bin/maestro --device "$SIM" hierarchy | grep -i '<text>'`.

### 4.1 `loop.yaml` — three edits

- Screenshot names take a `TAG` so three stages can reuse the flow: replace `p2b-loop-n${N}-` with `${TAG}-n${N}-` (three lines).
- After `- assertVisible: "Spinfolk"` add:
  ```yaml
  - waitForAnimationToEnd
  - takeScreenshot: docs/plans/phase-5/evidence/${TAG}-n${N}-home
  ```
- After `- assertVisible: "Dial, ${N} players, ready to spin"` (the first one) add:
  ```yaml
  - waitForAnimationToEnd
  - takeScreenshot: docs/plans/phase-5/evidence/${TAG}-n${N}-ready
  ```
- Update the header comment: `# Run with: maestro test -e N=<players> -e TAG=<prefix> tool/maestro/loop.yaml`.

### 4.2 `screens.yaml` — tap name fields by label

Replace the `runFlow … when … commands` block's two coordinate taps with label taps, and drop `Y1` / `Y2` from the header comment:
```yaml
      - tapOn: "Name for player 1.*"
      - inputText: "Abcdefghijklmnopqrstuvwxyz0123456789ABCD"
      - tapOn: "Name for player 2.*"
      - inputText: "Wxyzabcdefghijklmnopqrstuvwxyz0123456789"
```
If the label does not match (check with `maestro hierarchy`), try the hint text `Player 1` / `Player 2`; only then fall back to `point:` coordinates measured from a screenshot. Keep the `TYPE` switch.

### 4.3 `phase3.yaml` — add the background-mid-spin check (P3-D3)

Append after the last line (`- tapOn: "Done"`):
```yaml
- tapOn: "Pass"                             # revealed -> ready, round 2
- assertVisible: "Round 2 · .* players"
- tapOn: "Spin"
- pressKey: Home                            # background mid-spin (P3-D3)
- launchApp: { stopApp: false }
- extendedWaitUntil: { visible: "Taker .*", timeout: 3000 }
- assertVisible: "Replay announcement"
- takeScreenshot: docs/plans/phase-5/evidence/p3-background-return
```
The flow must end with an active session on screen: the gate's corrupt-row step depends on it.

### 4.4 New `la_shot.yaml` — island + Lock Screen capture (D10)

```yaml
# Subflow: screenshots of the Dynamic Island and of the Live Activity card, then back to the app.
# Called with env NAME. Notification Center shows Live Activities like the Lock Screen does.
appId: in.appamania.spinfolk
---
- pressKey: Home
- waitForAnimationToEnd
- takeScreenshot: docs/plans/phase-5/evidence/p4-${NAME}-island
- swipe: { start: "20%, 1%", end: "20%, 70%", duration: 600 }
- waitForAnimationToEnd
- takeScreenshot: docs/plans/phase-5/evidence/p4-${NAME}-lock
- pressKey: Home
- launchApp: { stopApp: false }
```
If the `-lock` screenshot does not show Notification Center with the card: second attempt, replace the swipe with `- pressKey: Lock` then `- pressKey: Home` (wakes to the Lock Screen), and check that `launchApp` still brings the app back. If neither works, remove the lock capture, keep the island capture, mark the Lock Screen part of P4-D1/D2/D3 NOT VERIFIED and add "Device → Lock (⌘L), screenshot (⌘S) in each phase" to the owner checklist. The first time, iOS shows "Allow / Don't Allow" under the card; that is expected and is not a failure.

### 4.5 `phase4.yaml` — replace the whole body

```yaml
# Live Activity: start, updates after reveal / mode / next round. Leaves the app in the background.
appId: in.appamania.spinfolk
---
- launchApp: { clearState: true }
- tapOn: "New game"
- tapOn: "Start session"
- assertVisible: "Round 1 · .* players"
- runFlow: { file: la_shot.yaml, env: { NAME: 1-started } }     # P4-D1: card, no roles
- tapOn: "Spin"
- extendedWaitUntil: { visible: "Taker .*", timeout: 15000 }
- waitForAnimationToEnd
- runFlow: { file: la_shot.yaml, env: { NAME: 2-revealed } }    # P4-D2/D3: two role tiles
- tapOn: "Truth"
- runFlow: { file: la_shot.yaml, env: { NAME: 3-challenge } }   # mode shown
- tapOn: "Next Round"
- assertVisible: "Round 2 · .* players"
- runFlow: { file: la_shot.yaml, env: { NAME: 4-next } }        # round 2
- tapOn: "Session and settings"
- assertNotVisible: "Lock Screen updates are off in iOS Settings."
- tapOn: "Done"
- pressKey: Home
```
There is no mid-spin capture on purpose (D11).

### 4.6 New `phase4_end.yaml` — relaunch and end (P4-D6, P4-D5)

```yaml
# Relaunch keeps exactly one activity; End Session removes it.
appId: in.appamania.spinfolk
---
- launchApp                                                     # cold start
- assertVisible: "Resume game"
- runFlow: { file: la_shot.yaml, env: { NAME: 5-relaunch } }    # P4-D6: one activity, not two
- tapOn: "Resume game"
- tapOn: "Session and settings"
- scrollUntilVisible: { element: "End Session" }
- tapOn: "End Session"
- extendedWaitUntil: { visible: "End this session?", timeout: 5000 }
- tapOn: "End Session"
- assertVisible: "Good game."
- runFlow: { file: la_shot.yaml, env: { NAME: 6-ended } }       # P4-D5: no island, no card
```

### 4.7 New `reduced.yaml` — Reduce Motion + Reduce Transparency (P1-6, P2-15)

```yaml
# Run with both accessibility settings ON. A normal spin takes at least 4.4 s; the 3 s limit proves the short path.
appId: in.appamania.spinfolk
---
- launchApp: { clearState: true }
- tapOn: "New game"
- tapOn: "Start session"
- assertVisible: "Dial, .* players, ready to spin"
- takeScreenshot: docs/plans/phase-5/evidence/p1-reduced-ready
- tapOn: "Spin"
- extendedWaitUntil: { visible: "Taker .*", timeout: 3000 }
- takeScreenshot: docs/plans/phase-5/evidence/p1-reduced-revealed
- tapOn: "Session and settings"
- extendedWaitUntil: { visible: "Edit Players", timeout: 5000 }
- takeScreenshot: docs/plans/phase-5/evidence/p1-reduced-sheet
```

`edit.yaml` and `history.yaml` need only the `sed` above.

---

## 5. `tool/final_gate.sh` and cleanup

### 5.1 Create `tool/final_gate.sh` (`chmod +x`)

Written for macOS bash 3.2. Not run during planning: treat it as the specification, fix what the first run shows, keep the stage names and the evidence layout.

```bash
#!/usr/bin/env bash
# Final device pass: every simulator check deferred from Phases 1-4, in one run.
#   tool/final_gate.sh [stage ...]        no arguments = all stages, in order
# Stages: static release loop edit history lifecycle activity se motion ios18
# Logs and screenshots: docs/plans/phase-5/evidence/ (git-ignored).
# A failing stage does not stop the run; the exit code is 1 if any stage failed.
set -uo pipefail
cd "$(dirname "$0")/.."

SIM="${SIM:-2938F81B-D7F8-4DFD-81D8-968C25C04F1F}"     # iPhone 17 Pro, iOS 26.5 (Dynamic Island)
SE="${SE:-584BBD07-5D8E-4995-A740-1155986A238E}"       # "Spinfolk SE3", iOS 26.5
SIM18="${SIM18:-66C64697-4A19-4C8F-85FE-3FEE1469323D}" # iPhone 16e, iOS 18.6 (glass fallback)
APP=in.appamania.spinfolk
EVID=docs/plans/phase-5/evidence
BUILT=build/ios/iphonesimulator/Runner.app
MAESTRO="$HOME/.maestro/bin/maestro"
mkdir -p "$EVID"

boot()    { xcrun simctl boot "$1" 2>/dev/null || true; xcrun simctl bootstatus "$1" -b >/dev/null; }
build()   { fvm flutter build ios --simulator --debug "$@"; }
install() { xcrun simctl uninstall "$1" "$APP" 2>/dev/null || true; xcrun simctl install "$1" "$BUILT"; }
flow()    { local dev=$1; shift; "$MAESTRO" --device "$dev" test "$@"; }
shot()    { xcrun simctl io "$1" screenshot "$EVID/$2.png" >/dev/null; }
data()    { xcrun simctl get_app_container "$1" "$APP" data; }
db()      { find "$(data "$1")" -name spinfolk.db | head -1; }
a11y()    { xcrun simctl spawn "$1" defaults write com.apple.Accessibility "$2" -bool "$3"; }
eq()      { [ "$2" = "$3" ] || { echo "FAIL $1: got '$2', want '$3'"; exit 1; }; echo "ok   $1 = $2"; }

stage_static() {                                   # P1-9, P5-1
  fvm dart run build_runner build --delete-conflicting-outputs
  git diff --exit-code lib/core/di/injection.config.dart
  fvm dart format --set-exit-if-changed .
  fvm flutter analyze
  fvm flutter test
  tool/check_rules.sh
}

stage_release() {                                  # P5-2
  fvm flutter build ios --release --no-codesign
  local a=build/ios/iphoneos/Runner.app x=build/ios/iphoneos/Runner.app/PlugIns/SpinfolkWidget.appex b
  pb() { /usr/libexec/PlistBuddy -c "Print :$2" "$1/Info.plist"; }
  eq 'app id' "$(pb $a CFBundleIdentifier)" "$APP"
  eq 'widget id' "$(pb $x CFBundleIdentifier)" "$APP.SpinfolkWidget"
  for b in $a $x; do
    eq "version $b" "$(pb $b CFBundleShortVersionString)" 0.1.0
    eq "build $b" "$(pb $b CFBundleVersion)" 1
    eq "min os $b" "$(pb $b MinimumOSVersion)" 17.0
  done
  eq 'live activities' "$(pb $a NSSupportsLiveActivities)" true
  eq 'url scheme' "$(pb $a CFBundleURLTypes:0:CFBundleURLSchemes:0)" spinfolk
  eq 'deep linking' "$(pb $a FlutterDeepLinkingEnabled)" false
  eq 'extension point' "$(pb $x NSExtension:NSExtensionPointIdentifier)" com.apple.widgetkit-extension
  eq 'icon name' "$(pb $a CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName)" AppIcon
  eq 'forbidden keys' "$(plutil -p $a/Info.plist | grep -cE 'UIBackgroundModes|UsageDescription')" 0
  [ -f $a/Assets.car ] || { echo 'FAIL Assets.car missing'; exit 1; }
  eq 'team ids' "$(codesign -dv $a 2>&1 | grep 'TeamIdentifier=' | grep -vc 'not set')" 0
}

stage_loop() {                                     # P2-12 P2-13 P2-17 P1-2 P1-3 P1-8 P2b-S1 P2b-S5
  boot "$SIM"
  local n
  for n in ${COUNTS:-2 3 5 7 59 60}; do
    build --dart-define=SPINFOLK_INITIAL_COUNT="$n"
    install "$SIM"
    flow "$SIM" -e N="$n" -e TAG=loop tool/maestro/loop.yaml
  done
}

stage_edit() {                                     # P2-16 P1-1
  boot "$SIM"; build; install "$SIM"
  flow "$SIM" tool/maestro/edit.yaml
}

stage_history() {                                  # P2b-S5 P2b-S1 (Undo)
  boot "$SIM"; build; install "$SIM"
  flow "$SIM" tool/maestro/history.yaml
}

stage_lifecycle() {                                # P3-D1 D2 D3 D4 D5 D7
  boot "$SIM"; build; install "$SIM"
  flow "$SIM" tool/maestro/phase3.yaml             # ends with an active session, Announcements off
  xcrun simctl terminate "$SIM" "$APP" || true
  sqlite3 "$(db "$SIM")" 'DELETE FROM player WHERE seat = 1;'      # P3-D5: SQL-legal corruption
  xcrun simctl launch "$SIM" "$APP"; sleep 4
  shot "$SIM" p3-corrupt                           # expect "Couldn't restore the last game" on Home
  flow "$SIM" -e N=8 -e TAG=d4 tool/maestro/loop.yaml              # plays and ends one session
  xcrun simctl terminate "$SIM" "$APP" || true
  eq 'active session rows' "$(sqlite3 "$(db "$SIM")" 'SELECT count(*) FROM session;')" 0      # P3-D4
  eq 'archived games' "$(sqlite3 "$(db "$SIM")" 'SELECT count(*) FROM game;')" 1
  plutil -p "$(data "$SIM")/Library/Preferences/$APP.plist" \
    | grep -E '"(flutter\.)?announce" => (0|false)' \
    || { echo 'FAIL announce pref not kept as off'; exit 1; }                                 # P3-D1 + D4
}

stage_activity() {                                 # P4-D1 ... D6
  boot "$SIM"; build; install "$SIM"
  flow "$SIM" tool/maestro/phase4.yaml             # leaves the app in the background, round 2
  local id; id=$(sqlite3 "$(db "$SIM")" 'SELECT id FROM session;')
  [ -n "$id" ] || { echo 'FAIL no active session id'; exit 1; }
  xcrun simctl openurl "$SIM" "spinfolk://session/$id"; sleep 2; shot "$SIM" p4-link-warm      # game, round 2
  xcrun simctl terminate "$SIM" "$APP"
  xcrun simctl openurl "$SIM" "spinfolk://session/$id"; sleep 5; shot "$SIM" p4-link-cold      # game, not Home
  xcrun simctl openurl "$SIM" "spinfolk://session/00000000000000000000000000000000"; sleep 2
  shot "$SIM" p4-link-foreign                      # unchanged
  flow "$SIM" tool/maestro/phase4_end.yaml
}

stage_se() {                                       # P2-14 P2-17
  boot "$SE"
  trap 'xcrun simctl ui "$SE" content_size large' EXIT
  build --dart-define=SPINFOLK_INITIAL_COUNT=2
  local size
  for size in large extra-extra-extra-large accessibility-extra-extra-extra-large; do
    xcrun simctl ui "$SE" content_size "$size"
    install "$SE"
    flow "$SE" -e TAG="$size" -e TYPE=yes tool/maestro/screens.yaml
  done
}

stage_motion() {                                   # P1-6 P2-15
  boot "$SIM"; build; install "$SIM"
  trap 'a11y "$SIM" ReduceMotionEnabled NO; a11y "$SIM" EnhancedBackgroundContrastEnabled NO' EXIT
  a11y "$SIM" ReduceMotionEnabled YES
  a11y "$SIM" EnhancedBackgroundContrastEnabled YES          # Reduce Transparency
  flow "$SIM" tool/maestro/reduced.yaml
}

stage_ios18() {                                    # P1-7 P2b-S1 (fallback material)
  boot "$SIM18"; build; install "$SIM18"
  flow "$SIM18" -e N=8 -e TAG=ios18 tool/maestro/loop.yaml
  xcrun simctl shutdown "$SIM18"
}

[ $# -eq 0 ] && set -- static release loop edit history lifecycle activity se motion ios18
failed=0; table=''
for s in "$@"; do
  declare -f "stage_$s" >/dev/null || { echo "unknown stage: $s"; exit 2; }
  echo "=== $s"
  ( set -e; "stage_$s" ) 2>&1 | tee "$EVID/$s.log"
  if [ "${PIPESTATUS[0]}" -eq 0 ]; then table="$table\nPASS  $s"; else table="$table\nFAIL  $s"; failed=1; fi
done
printf "$table\n" | tee "$EVID/summary.txt"
exit "$failed"
```

Notes for the first run:
- `content_size`, the two `defaults` keys, `openurl` and the `sqlite3` path were used successfully in Phases 1–2 on these simulators. The prefs plist key and the `pressKey` / Notification Center steps are first-time uses.
- If `stage_lifecycle`'s plist line fails only because the key is stored differently, print the plist (`plutil -p`), fix the pattern, and keep `p3-prefs-after-kill.png` as the second proof.
- If the `game` count is not 1, read the table (`SELECT id, rounds FROM game;` with the real column names from `lib/features/session/data/session_db.dart`) before changing the expectation.
- The `flutter.` prefix alternative and the `EXIT` traps are deliberate; do not remove them.

### 5.2 Cleanup

```sh
git rm tool/phase2_gate.sh tool/phase3_gate.sh tool/phase4_gate.sh
grep -rn 'phase[234]_gate' --include='*.sh' --include='*.yaml' --include='*.md' . | grep -v '^./docs/plans/phase-[0-4b-]*/'   # nothing outside the old plans
```
Earlier plan documents keep their references (history, not edited). `tool/add_widget_target.rb` and `tool/check_rules.sh` stay unchanged.

---

## 6. Run the gate and review the evidence

```sh
open -a Simulator
tool/final_gate.sh static
tool/final_gate.sh release
tool/final_gate.sh loop
tool/final_gate.sh edit history
tool/final_gate.sh lifecycle
tool/final_gate.sh activity
tool/final_gate.sh se
tool/final_gate.sh motion
tool/final_gate.sh ios18
```
After repairs, finish with **one uninterrupted `tool/final_gate.sh`** (all stages) on the final code; that run's `summary.txt` is the one reported (P5-9). If the full run cannot fit a single tool call, run it in the background and wait for it.

Then open every PNG in `docs/plans/phase-5/evidence/` with the image reader and judge it against the artboard named below. Write one verdict per §6 row of the PRD.

| Screenshots | Look for | Artboard | Items |
|---|---|---|---|
| `loop-n{2,3,5,7}-revealed` | numbered discs, haloed taker (teal) and giver (coral), bottle neck on the taker, bottle straight; dotted coral arc for 3, 5, 7 and none for 2; role cards say TAKER / GIVER in text; Truth and Dare equal width, Pass separate | `Revealed`, `Dial` | P2-13, P1-8 |
| `loop-n{59,60}-revealed` | ticks, every fifth labelled, selected ticks long and coloured with their numbers; arc for 59, none for 60 | `Crowd60`, `Dial` | P2-13 |
| `loop-n*-home`, `-ready` | glass pill, settings button and Spin bar show real glass (edge highlight, not a flat grey fill); labels legible; nothing overlaps the dial | `Home`, `Ready2` | P1-3, P2b-S1 |
| `loop-n*-sheet`, `-summary` | scrim covers the game with no native bar painted over it; sheet controls intact; summary stats correct for 3 rounds | `Settings`, `EndSummary` | P2-17, P2b-S4 |
| `p2b-edit` | new count in the pill, still "Round 1" | `Ready2` | P2-16 |
| `p2b-history-*` | TODAY section, row with "2 rounds", detail with ROUND LOG, undo toast with a white Undo and navy text | `History`, `HistoryDetail`, `HistoryUndo` | P2b-S5, P2b-S1 |
| `p3-sheet-voice`, `p3-prefs-after-kill` | Announcements switch off in both; slider and Play sample present | `Settings` | P3-D1, P3-D7 |
| `p3-resume-after-kill`, `p3-background-return` | revealed state with role cards and Replay; not Ready, not Spinning | `Revealed` | P3-D2, P3-D3 |
| `p3-corrupt` | Home with "Couldn't restore the last game", no Resume button | `Home` | P3-D5 |
| `p2b-se-<size>-*` (7 × 3) | no overflow stripes, nothing clipped or overlapping, native bar labels inside their capsules, long names ellipsised with "· P1" kept | all screens | P2-14 |
| `p1-reduced-*` | islands opaque but legible; reveal reached (the flow's 3 s limit is the proof of the short spin) | — | P1-6, P2-15 |
| `ios18-n8-*` | same shapes with material instead of glass; labels legible; full loop passed | — | P1-7, P2b-S1 |
| `p4-1-started-*` | island present; card is the one-line "ready" layout, no roles | `LiveActivity` | P4-D1 |
| `p4-2-revealed-*`, `p4-3-challenge-*`, `p4-4-next-*` | two role tiles with the same players as the app; mode shown after Truth; round 2 after Next; compact island shows mark + `giver › taker` | `LiveActivity` | P4-D2, P4-D3 |
| `p4-link-warm`, `-cold`, `-foreign` | game screen at round 2 for warm and cold; foreign id changes nothing | — | P4-D4 |
| `p4-5-relaunch-*` | exactly one card / island | — | P4-D6 |
| `p4-6-ended-*` | no island, no card | — | P4-D5 |
| `p5-home-icon`, `p5-launch` | the new icon; navy launch | `Logo` | P5-3, P5-4 |

Rules for verdicts: PASS needs the screenshot or log line named. A doubtful image is reported as doubtful with what looks off. FAIL caused by the flow → repair (budget in §0). FAIL caused by the app → D8.

If the Live Activity never appears (`p4-1-started-*` show nothing):
```sh
xcrun simctl spawn "$SIM" log show --last 3m --style compact --predicate 'process == "Runner" OR subsystem CONTAINS[c] "activitykit"' | tail -80 > docs/plans/phase-5/evidence/p4-activity.log
```
Report P4-D1 FAIL with the relevant lines; do not edit `LiveActivityBridge.swift` or the widget without the coordinator.

Reset check (P5-11):
```sh
xcrun simctl spawn "$SIM" defaults read com.apple.Accessibility ReduceMotionEnabled                  # 0
xcrun simctl spawn "$SIM" defaults read com.apple.Accessibility EnhancedBackgroundContrastEnabled    # 0
xcrun simctl ui "$SE" content_size                                                                   # large
```

---

## 7. README and spec amendment

### 7.1 Rewrite `README.md`

Replace the whole file. Keep it to about this length; fill the two bracketed facts from the real run; run every command in it once (P5-7).

````markdown
# Spinfolk

Offline, single-phone Truth-or-Dare for iPhone. One bottle, 2–60 players, no accounts, no network.

Status: version 0.1.0 (1). Verified on iOS simulators (26.5 and 18.6) on [date]. Not yet run on a real device or uploaded to TestFlight; both need an Apple team ID.

## Gameplay

- Pick 2–60 players on the wheel; names are optional.
- Spin. The bottle's **neck** points at the **taker** (teal). The **base** points at the **giver** (coral), who sets the challenge.
- The taker chooses Truth or Dare, or anyone passes. Then Next Round.
- The result is announced aloud (voice and speed in the session sheet) and shown on the Lock Screen and Dynamic Island.
- A game survives closing the app. Ended games are kept in History on the phone.

**Odd player counts.** Nobody sits exactly opposite the taker, so the giver is picked at random from the two nearest-opposite seats. The bottle stays straight; a dotted arc shows which seat was chosen.

## Setup

Requires macOS with Xcode [version used], and [FVM](https://fvm.app).

```sh
fvm install                                   # Flutter 3.50.1 / Dart 3.14, from .fvmrc
fvm flutter config --enable-swift-package-manager
fvm flutter pub get
fvm dart run build_runner build --delete-conflicting-outputs   # regenerates lib/core/di/injection.config.dart
```

Package versions are pinned exactly in `pubspec.yaml`; `pubspec.lock` is committed. iOS dependencies come through Swift Package Manager only (no CocoaPods).

## Run and test

```sh
fvm flutter run                               # on a booted iOS simulator
fvm dart format --set-exit-if-changed .
fvm flutter analyze
fvm flutter test
tool/check_rules.sh                           # architecture rules
tool/final_gate.sh                            # full simulator pass (Maestro); see the script header
swift tool/make_icon.swift ios/Runner/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
```

## Architecture

Lean Clean Architecture, feature-first. Full detail: [docs/spec-v2.md](docs/spec-v2.md).

```
lib/app/         router (go_router, redirect-driven), navigator, tokens, shared UI
lib/core/        dependency injection (get_it + injectable), failures
lib/features/    session · setup · game · settings · history · home
                 each: domain (pure Dart) / data (sqflite, shared_preferences) / presentation (bloc, cubit, pages)
lib/platform/    MethodChannel bridge, speech announcer, Live Activity sync, native glass views
ios/Runner/Native/     SwiftUI glass picker and action bar, AVSpeechSynthesizer, ActivityKit bridge
ios/SpinfolkWidget/    Live Activity and Dynamic Island
```

State is flutter_bloc only: no `setState`, no `BuildContext` below the widgets. The outcome of a spin is saved before the animation starts, so it can never be re-rolled.

## iOS and signing

- iOS 17.0 or later. Liquid Glass on iOS 26+, system material on 17–25.
- Bundle IDs: `in.appamania.spinfolk` and `in.appamania.spinfolk.SpinfolkWidget`.
- The repo contains no team ID, certificate or profile, and must not. Simulator builds need none. For a device build pass your team on the command line: `FLUTTER_XCODE_DEVELOPMENT_TEAM=<team id> fvm flutter build ios --release`.
- No microphone permission, no background modes, no App Group.

## Known limits

- iPhone, portrait, dark appearance, English only.
- The Live Activity updates only while the app is running and lasts at most 8 hours.
- Announcements use the voices installed on the phone; without one the roles are shown but not spoken.
- Not yet checked on hardware: audio ducking and the mute switch, haptics, frame pacing, VoiceOver.
- The app does not write challenges. The group does.
````

Check the device-build line before leaving it in: if `FLUTTER_XCODE_DEVELOPMENT_TEAM` cannot be confirmed from Flutter 3.50.1's own documentation or source (`grep -rn 'FLUTTER_XCODE_' "$(fvm flutter --version --machine | sed -n 's/.*"flutterRoot": "\(.*\)".*/\1/p')/packages/flutter_tools/lib" | head`), replace that sentence with "A device build needs your Apple team selected in Xcode locally; do not commit it." Do not run a device build to test it.

### 7.2 Spec amendment — append to `docs/spec-v2.md`

```markdown

## Amendments — Phase 5 (2026-11-22)

- **Dependency:** `material_ui` 1.11.1 is a direct runtime dependency. Flutter 3.50 moved Material out of the SDK; approved in `docs/plans/phase-0-1/prd.md` (open question 1). This completes the A9 runtime list.
- **Phase 5 scope and the final device pass** are defined in `docs/plans/phase-5/prd.md`. All deferred simulator checks run through `tool/final_gate.sh`; the per-phase gate scripts are removed.
- **App icon** is generated by `tool/make_icon.swift` from the `Logo.dc.html` geometry; one 1024 px image, no variants.
```

---

## 8. Final static block

```sh
tool/final_gate.sh static release
swift tool/make_icon.swift /tmp/spinfolk-icon-check.png \
  && cmp /tmp/spinfolk-icon-check.png ios/Runner/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png && echo 'icon reproducible'
git status --short                 # only intended files; nothing under docs/plans/*/evidence/
git diff --stat phase-4
```
Expected changes against `phase-4`: `README.md`, `docs/spec-v2.md`, `docs/plans/phase-5/*`, `ios/Runner/Assets.xcassets/AppIcon.appiconset/*` (15 deletions, 1 addition, `Contents.json`), `ios/Runner/Base.lproj/LaunchScreen.storyboard`, `tool/final_gate.sh`, `tool/make_icon.swift`, `tool/maestro/*.yaml` (6 edited, 3 added), three deleted gate scripts. Anything under `lib/`, `test/` or `ios/Runner/Native/` is there only because of a reported D8 fix. `pubspec.yaml`, `pubspec.lock` and `project.pbxproj` are unchanged.

---

## 9. Report (reply to the coordinator; no report file)

1. What changed, by file.
2. P5-1 … P5-13: PASS / FAIL with real output (the gate's `summary.txt`, the release stage's `ok` lines, the secret-scan output).
3. The deferred-item table of PRD §6 with a verdict per row and the screenshot or log line that supports it. NOT VERIFIED rows state the reason and the attempts.
4. Flow repairs made (file, step, why) and any app change made under D8.
5. App defects found and not fixed.
6. The owner checklist of PRD §8, with any item that fell back to manual added.
7. Open questions 2 and 3 of the PRD, still open.
8. The team-ID question of PRD §9.1, quoted exactly, and the sentence "Nothing was signed, archived or uploaded."
9. Absolute path of the evidence folder.

Suggested commits on `phase-5` (only when asked): `Phase 5: app icon from canvas geometry and dark launch screen` · `Phase 5: final device gate, repaired Maestro flows, old gate scripts removed` · `Phase 5: README and spec amendment` · (if any) `Phase 5: fix <defect> found by the device pass`.

---

## 10. STOP — TestFlight is blocked

Do not continue past the report. Ask the owner the question in PRD §9.1 word for word. Do not guess a team ID, do not read one from Xcode's preferences or the keychain, do not create App Store Connect records, do not ask for passwords, app-specific passwords or API keys.

When the owner has answered all three points, a short addendum plan is written first (it is not part of this phase). Its outline, to be verified then, not now:
1. Decide PRD questions 2 (iPad) and 3 (export compliance) and apply them.
2. `FLUTTER_XCODE_DEVELOPMENT_TEAM=<id>` in the shell only; `fvm flutter build ipa --release`; `tool/check_rules.sh` still passes afterwards (no team written to the project file; if Xcode writes one, `git checkout ios/Runner.xcodeproj/project.pbxproj`).
3. Real-device items 6–10 of the owner checklist.
4. Upload from Xcode Organizer or Transporter by the owner, signed in as themselves.

---

## 11. Branch flow (coordinator runs this, not the implementer)

Preconditions: Phase 5 reviewed and committed; every phase branch pushed; working tree clean. History is linear, so each merge is conflict-free; `--no-ff` keeps one merge commit per phase.

```sh
cd /Users/sp/Dev/Games/Spin-Folk
git status --short                                   # must print nothing
git push -u origin phase-5
git fetch origin --prune
for b in phase-0-1 phase-2 phase-2b phase-3 phase-4 phase-5; do
  [ "$(git rev-parse "$b")" = "$(git rev-parse "origin/$b")" ] || echo "NOT PUSHED: $b"
done                                                  # must print nothing

git switch -c dev origin/main
git merge --no-ff phase-0-1 -m "Merge phase-0-1: Flutter baseline and native glass proof"
git merge --no-ff phase-2   -m "Merge phase-2: game rules, SQLite session, screens, dial and spin"
git merge --no-ff phase-2b  -m "Merge phase-2b: Flow v2, History, adaptive glass"
git merge --no-ff phase-3   -m "Merge phase-3: native speech, voice settings, prefs, lifecycle"
git merge --no-ff phase-4   -m "Merge phase-4: Live Activity and Dynamic Island"
git merge --no-ff phase-5   -m "Merge phase-5: proof, icon, README, final device gate"

git diff --quiet dev phase-5 && echo "dev tree == phase-5 tree"     # must print the message
tool/final_gate.sh static                                          # green on dev
git log --oneline --graph -14

git push -u origin dev
gh pr create --base main --head dev \
  --title "Spinfolk 0.1.0: playable game, speech, History, Live Activity" \
  --body-file /tmp/spinfolk-pr.md
gh pr view --web
```

Add the session's commit attribution trailer to each merge message if the session requires one (a second `-m "Co-Authored-By: …"`).

Write `/tmp/spinfolk-pr.md` first (outside the repo), from the Phase 5 report:

```markdown
## What this is
Spinfolk 0.1.0 (1): offline single-phone Truth-or-Dare for iPhone. Phases 0–5 of docs/spec-v2.md, merged one phase at a time.

## Phases
- phase-0-1: Flutter 3.50.1 baseline, native glass picker and action bar
- phase-2: selection and rotation rules, SQLite session, game screens
- phase-2b: Home, History, round log, adaptive glass buttons
- phase-3: native speech, voice settings, preferences, lifecycle
- phase-4: Live Activity and Dynamic Island
- phase-5: icon, launch screen, README, release audit, final simulator gate

## Verification
<paste the final_gate.sh summary table>
<paste the deferred-item verdict table; list every NOT VERIFIED row>

## Not done
- No real-device run and no TestFlight upload: the Apple team ID is not confirmed. The repo contains no signing material.
- Owner checklist (manual checks): see docs/plans/phase-5/prd.md §8.
- Open: iPad support, export-compliance key (docs/plans/phase-5/prd.md §9).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

Do not merge the PR; the owner reviews it. Do not delete the phase branches.
