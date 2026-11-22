# Spinfolk — Phase 4: Implementation Guidelines

Read `prd.md` (this folder), `docs/spec-v2.md` A7 / A8, `docs/plans/phase-3/guidelines.md`, and the Phase 2b and Phase 3 reports first. The spec's architecture is fixed. Decision ids (D1…) refer to `prd.md` §5.

## 0. Ground rules and reconcile step

- All earlier ground rules apply (every command through `fvm`, from `/Users/sp/Dev/Games/Spin-Folk`; no `setState`; blocs and cubits never see `BuildContext`; navigation only through `AppNavigator`; widget callbacks only forward intent).
- **No new dependencies, no Podfile, no App Group, no entitlements file, no `DEVELOPMENT_TEAM`, no `UIBackgroundModes`.** Never invent a team id.
- Do not open Xcode's GUI to edit the project. The project file changes only through `tool/add_widget_target.rb`.
- No `.glassEffect`, no material imitation in the widget.
- **No simulator, no Maestro in this phase** (owner decision). Gate = the static block in §9 plus the bundle inspection in §4. Device checks P4-D1…D8 are written as flows and reported **NOT VERIFIED**.
- Evidence files (`docs/plans/*/evidence/`) are git-ignored. Never force-add them.
- Report honestly; paste real output.
- Git: branch `phase-4` from the tip of `phase-3`. Commit only when told; never push.

Start condition:
```sh
git switch phase-3 && git status --short          # must be clean
fvm dart run build_runner build --delete-conflicting-outputs
fvm dart format --set-exit-if-changed . && fvm flutter analyze && fvm flutter test && tool/check_rules.sh
fvm flutter build ios --simulator --debug
git switch -c phase-4
```
If any of these fail, Phase 3 is not finished: stop and report.

**Reconcile.** This plan was written before the Phase 2b and Phase 3 code existed. Check each row against the code before editing:

| This plan assumes | Check | If different |
|---|---|---|
| `ios/Runner/Native/NativeChannel.swift` is the Phase 3 file (singleton `shared`, `attach(messenger:)`, private `handle`, `speech` property). | read the file | §2 gives the complete Phase 4 file; carry over anything Phase 3 added beyond its plan. |
| `lib/platform/native_bridge.dart` owns `MethodChannel('spinfolk/native')` and `_onCall`. | read the file | Add to it; do not create a second channel object. |
| `SettingsCubit` builds each `SettingsState` explicitly. | read the file | Add `activityStatus` the same way its other fields are handled. |
| One `AppLifecycleListener`, in `lib/app/app.dart` (`onHide` → `AppBackgrounded`). | `grep -rn AppLifecycleListener lib/` | Add `onResume` to the one that exists. |
| `SessionLinkOpened(id)`: a matching id in the not-yet-resumed state resumes the session; a match in an active game changes nothing; mismatches are ignored. | `session_bloc.dart` + its test | If 2b's Home hub changed the pre-resume state, the event must still end in the active game state. If it does not, stop and report. |
| Bloc state exposes the last logged round (what Ready's "LAST P3 → P7 · Truth" line shows). | `session_state.dart`, the Ready panel in `game_page.dart` | Use that value in `activityPayload`. If there is none in state: stop and report (fallback in `prd.md` §8). |
| "Session gone" = the state stops carrying a session (2b: end summary, Home). | states + redirect | Define one private `Session? _sessionOf(SessionState)` in `live_activity_sync.dart` and use it everywhere. |
| `Runner` target phases end `… Embed Frameworks, Thin Binary`; group `Runner/Native` exists; three configurations. | `ruby -rxcodeproj -e 'p=Xcodeproj::Project.open("ios/Runner.xcodeproj"); t=p.targets.find{|x|x.name=="Runner"}; puts t.build_phases.map(&:display_name).join(" > "), t.build_configurations.map(&:name).join(",")'` | The script aborts with a message if "Thin Binary" or the group is missing; report it instead of editing the script blindly. |
| `test/support/fake_native.dart` and the harness from Phase 3. | read | Extend. |

Step order: 1 plist → 2 Swift files → 3 project script → 4 build + bundle inspection → 5 `NativeBridge` → 6 `LiveActivitySync` → 7 `SettingsCubit` + sheet line → 8 wiring → 9 rules + verify → 10 deferred flows. Do the native half (1–4) first and get a green build before touching Dart.

All Swift and Ruby below was compiled / run on a scratch copy of the repo on 2026-11-22 (Xcode 27.2, Flutter 3.50.1, xcodeproj 1.27.0). **It has never been launched.** Keep it as written unless the compiler or the reconcile step forces a change, and report every change.

---

## 1. `ios/Runner/Info.plist`

Edit the XML by hand (PlistBuddy re-sorts the file). Add inside the top-level `<dict>`:
```xml
	<key>NSSupportsLiveActivities</key>
	<true/>
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLName</key>
			<string>in.appamania.spinfolk</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>spinfolk</string>
			</array>
		</dict>
	</array>
```
Leave `FlutterDeepLinkingEnabled` = `false` as it is. Do not add `NSSupportsLiveActivitiesFrequentUpdates`, `UIBackgroundModes` or any usage description.
```sh
plutil -lint ios/Runner/Info.plist
git diff --stat ios/Runner/Info.plist      # insertions only
```

---

## 2. Swift

### 2.1 `ios/Runner/Native/SpinfolkAttributes.swift` — new, member of **both** targets
```swift
import ActivityKit
import Foundation

/// Shared by Runner and SpinfolkWidget (member of both targets).
struct SpinfolkAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var players: Int
    var round: Int
    var phase: String        // ready | revealed | challenge
    var takerLabel: String?
    var giverLabel: String?
    var takerSeat: Int?      // 0-based; display adds 1
    var giverSeat: Int?
    var mode: String?        // truth | dare
    var ended: Bool
  }

  var sessionId: String
  var startedAt: Date
}
```
Never rename or retype a `ContentState` field without changing both targets in the same commit; the two sides exchange it as JSON.

### 2.2 `ios/Runner/Native/LiveActivityBridge.swift` — new, Runner only
```swift
import ActivityKit
import Foundation

/// ActivityKit side of activity.sync / activity.end / activity.reconcile.
enum LiveActivityBridge {
  private static let lifetime: TimeInterval = 8 * 60 * 60

  private static var live: [Activity<SpinfolkAttributes>] {
    Activity<SpinfolkAttributes>.activities.filter {
      $0.activityState == .active || $0.activityState == .stale
    }
  }

  private static func isExpired(_ a: Activity<SpinfolkAttributes>) -> Bool {
    a.activityState == .stale || (a.content.staleDate.map { $0 <= Date() } ?? false)
  }

  private static func finish(_ a: Activity<SpinfolkAttributes>, rounds: Int? = nil) async {
    var state = a.content.state
    state.ended = true
    if let rounds { state.round = rounds }
    await a.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .immediate)
  }

  static func sync(_ args: [String: Any]) async -> [String: Any] {
    guard let id = args["sessionId"] as? String,
          let startedAt = args["startedAt"] as? Int,
          let players = args["players"] as? Int,
          let round = args["round"] as? Int,
          let phase = args["phase"] as? String else {
      return ["state": "error", "message": "bad arguments"]
    }
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      _ = await reconcile(keep: nil)
      return ["state": "disabled"]
    }
    let state = SpinfolkAttributes.ContentState(
      players: players, round: round, phase: phase,
      takerLabel: args["takerLabel"] as? String, giverLabel: args["giverLabel"] as? String,
      takerSeat: args["taker"] as? Int, giverSeat: args["giver"] as? Int,
      mode: args["mode"] as? String, ended: false)

    var current: Activity<SpinfolkAttributes>?
    for a in live {
      if a.attributes.sessionId == id, current == nil, !isExpired(a) {
        current = a
      } else {
        await finish(a)  // other sessions, duplicates, expired
      }
    }
    if let current {
      await current.update(ActivityContent(state: state, staleDate: current.content.staleDate))
      return ["state": "active"]
    }
    do {
      _ = try Activity.request(
        attributes: SpinfolkAttributes(
          sessionId: id, startedAt: Date(timeIntervalSince1970: Double(startedAt) / 1000)),
        content: ActivityContent(state: state, staleDate: Date().addingTimeInterval(lifetime)),
        pushType: nil)
      return ["state": "active"]
    } catch {
      return ["state": "error", "message": error.localizedDescription]
    }
  }

  static func end(sessionId: String, rounds: Int) async -> Bool {
    for a in live where a.attributes.sessionId == sessionId {
      await finish(a, rounds: rounds)
    }
    return true
  }

  static func reconcile(keep sessionId: String?) async -> Int {
    var ended = 0
    var kept = false
    for a in live {
      if let sessionId, a.attributes.sessionId == sessionId, !kept, !isExpired(a) {
        kept = true
      } else {
        await finish(a)
        ended += 1
      }
    }
    return ended
  }
}
```
Behaviour to preserve:
- `sync` ends foreign, duplicate and expired activities before it updates or requests.
- Disabled authorisation → every activity is ended and `disabled` is returned; nothing throws.
- A request that fails (for example from the background) returns `error` with the message.
- `end` and `reconcile` dismiss with `.immediate`.
- Wire seats are 0-based (`taker` / `giver` → `takerSeat` / `giverSeat`).

### 2.3 `ios/Runner/Native/NativeChannel.swift` — replace the Phase 3 file with
```swift
import Flutter
import Foundation

/// Owner of the shared spinfolk/native channel. Main thread only.
final class NativeChannel {
  static let shared = NativeChannel()

  private var channel: FlutterMethodChannel?
  private let speech = SpeechBridge()
  private var dartReady = false
  private var pendingSessionId: String?

  func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "spinfolk/native", binaryMessenger: messenger)
    self.channel = channel
    speech.onEvent = { [weak channel] state in
      channel?.invokeMethod("speech.event", arguments: ["state": state])
    }
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result) ?? result(FlutterMethodNotImplemented)
    }
  }

  /// spinfolk://session/<32 hex>. Anything else is dropped.
  func open(_ url: URL) {
    guard url.scheme == "spinfolk", url.host == "session" else { return }
    let id = url.lastPathComponent
    guard id.range(of: "^[0-9a-f]{32}$", options: .regularExpression) != nil else { return }
    if dartReady {
      channel?.invokeMethod("url.open", arguments: ["sessionId": id])
    } else {
      pendingSessionId = id
    }
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "speech.speak":
      guard let text = args["text"] as? String, !text.isEmpty else {
        return result(FlutterError(code: "speech", message: "empty text", details: nil))
      }
      do {
        try speech.speak(text: text, voiceId: args["voiceId"] as? String,
                         rate: args["rate"] as? Double ?? 0.5)
        result(nil)
      } catch {
        result(FlutterError(code: "speech", message: error.localizedDescription, details: nil))
      }
    case "speech.stop":
      speech.stop()
      result(nil)
    case "speech.voices":
      result(speech.voices(language: args["language"] as? String ?? "en"))
    case "url.ready":
      dartReady = true
      if let id = pendingSessionId {
        pendingSessionId = nil
        channel?.invokeMethod("url.open", arguments: ["sessionId": id])
      }
      result(nil)
    case "activity.sync":
      Task { @MainActor in result(await LiveActivityBridge.sync(args)) }
    case "activity.end":
      Task { @MainActor in
        result(["ok": await LiveActivityBridge.end(sessionId: args["sessionId"] as? String ?? "",
                                                   rounds: args["rounds"] as? Int ?? 0)])
      }
    case "activity.reconcile":
      Task { @MainActor in
        result(["ended": await LiveActivityBridge.reconcile(keep: args["sessionId"] as? String)])
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
```
Added versus Phase 3: `dartReady`, `pendingSessionId`, `open(_:)`, and the cases `url.ready`, `activity.sync`, `activity.end`, `activity.reconcile`. The speech cases are unchanged. `NativeChannel.shared` exists before the Flutter engine does, so a cold-start link is held even if `attach` has not run yet.

### 2.4 `ios/Runner/SceneDelegate.swift` — replace with
```swift
import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  // Cold start: the URL arrives in the connection options.
  override func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    connectionOptions.urlContexts.forEach { NativeChannel.shared.open($0.url) }
  }

  // Warm start.
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    URLContexts.forEach { NativeChannel.shared.open($0.url) }
  }
}
```
`FlutterSceneDelegate` implements both methods (verified with `nm`), so `override` + `super` is correct. Do not add `application(_:open:options:)` to `AppDelegate`: the app uses the scene life cycle and it would never be called.

### 2.5 `ios/SpinfolkWidget/Info.plist` — new
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>$(DEVELOPMENT_LANGUAGE)</string>
	<key>CFBundleDisplayName</key>
	<string>Spinfolk</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$(PRODUCT_NAME)</string>
	<key>CFBundlePackageType</key>
	<string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
	<key>CFBundleShortVersionString</key>
	<string>$(MARKETING_VERSION)</string>
	<key>CFBundleVersion</key>
	<string>$(CURRENT_PROJECT_VERSION)</string>
	<key>NSExtension</key>
	<dict>
		<key>NSExtensionPointIdentifier</key>
		<string>com.apple.widgetkit-extension</string>
	</dict>
</dict>
</plist>
```

### 2.6 `ios/SpinfolkWidget/SpinfolkLiveActivity.swift` — new, widget target only
```swift
import ActivityKit
import SwiftUI
import WidgetKit

private let teal = Color(red: 0x2D / 255, green: 0xD4 / 255, blue: 0xBF / 255)
private let coral = Color(red: 0xFF / 255, green: 0x7A / 255, blue: 0x59 / 255)
private let secondary = Color(red: 0xA9 / 255, green: 0xB6 / 255, blue: 0xCC / 255)
private let tertiary = Color(red: 0x81 / 255, green: 0x91 / 255, blue: 0xAB / 255)
private let dot = Color(red: 0x3A / 255, green: 0x4D / 255, blue: 0x74 / 255)
private let lockTint = Color(red: 20 / 255, green: 32 / 255, blue: 54 / 255).opacity(0.92)

@main
struct SpinfolkWidgetBundle: WidgetBundle {
  var body: some Widget { SpinfolkLiveActivity() }
}

private typealias State = SpinfolkAttributes.ContentState

extension SpinfolkAttributes.ContentState {
  var hasRoles: Bool { !ended && takerLabel != nil && giverLabel != nil }
  var modeText: String? { mode == "truth" ? "Truth" : (mode == "dare" ? "Dare" : nil) }
  var summary: String { "Round \(round) · \(players) players" }
  /// In `ready` the roles are the previous round's (from the round log).
  var caption: String? {
    if phase == "ready" { return hasRoles ? "Last round: \(modeText ?? "Pass")" : nil }
    return modeText
  }
  var spoken: String {
    if ended { return "Session ended, \(round) rounds" }
    guard hasRoles, let g = giverLabel, let t = takerLabel else { return "Round \(round), \(players) players" }
    return phase == "ready" ? "Round \(round), last round \(g) gave to \(t)" : "Round \(round), \(g) gives to \(t)"
  }
}

struct SpinfolkLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: SpinfolkAttributes.self) { context in
      LockScreenView(state: context.state)
        .fontDesign(.rounded)
        .foregroundStyle(.white)
        .activityBackgroundTint(lockTint)
        .activitySystemActionForegroundColor(.white)
        .widgetURL(sessionURL(context.attributes.sessionId))
    } dynamicIsland: { context in
      let s = context.state
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          HStack(spacing: 8) {
            LogoMark().frame(width: 24, height: 24)
            Text("Round \(s.round)").font(.subheadline).foregroundStyle(secondary)
          }
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text("\(s.players) players").font(.subheadline).foregroundStyle(secondary)
        }
        DynamicIslandExpandedRegion(.bottom) {
          ExpandedBottom(state: s).fontDesign(.rounded)
        }
      } compactLeading: {
        LogoMark().frame(width: 20, height: 20)
      } compactTrailing: {
        CompactTrailing(state: s).fontDesign(.rounded)
      } minimal: {
        LogoMark().frame(width: 22, height: 22)
      }
      .widgetURL(sessionURL(context.attributes.sessionId))
      .keylineTint(teal)
    }
  }
}

private func sessionURL(_ id: String) -> URL? { URL(string: "spinfolk://session/\(id)") }

private struct LockScreenView: View {
  let state: State

  var body: some View {
    Group {
      if state.hasRoles {
        VStack(alignment: .leading, spacing: 14) {
          HStack(spacing: 10) {
            LogoMark().frame(width: 28, height: 28)
            Text("Spinfolk").font(.headline.weight(.heavy))
            Spacer(minLength: 8)
            Text(state.summary).font(.subheadline).foregroundStyle(secondary).lineLimit(1)
          }
          HStack(spacing: 10) {
            RoleTile(title: "TAKER", label: state.takerLabel ?? "", color: teal)
            RoleTile(title: "GIVER", label: state.giverLabel ?? "", color: coral)
          }
          Text([state.caption, "Tap to return to the game"].compactMap { $0 }.joined(separator: " · "))
            .font(.footnote).foregroundStyle(secondary)
        }
      } else {
        HStack(spacing: 12) {
          LogoMark().frame(width: 28, height: 28)
          VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.subheadline.weight(.semibold))
            if let subtitle { Text(subtitle).font(.footnote).foregroundStyle(secondary) }
          }
          Spacer(minLength: 0)
        }
      }
    }
    .padding(16)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(state.spoken)
  }

  private var title: String {
    if state.ended { return "Session ended · \(state.round) rounds" }
    return state.round <= 1 ? "Session ready · \(state.players) players" : state.summary
  }

  private var subtitle: String? {
    if state.ended { return nil }
    return state.round <= 1 ? "No rounds yet. Open to spin." : "Ready for the next spin."
  }
}

private struct RoleTile: View {
  let title: String
  let label: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title).font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(color)
      Text(label).font(.title3.weight(.heavy)).lineLimit(1).minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 10).padding(.horizontal, 12)
    .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}

private struct ExpandedBottom: View {
  let state: State

  var body: some View {
    Group {
      if state.hasRoles {
        VStack(alignment: .leading, spacing: 8) {
          HStack(alignment: .bottom) {
            role("GIVER", state.giverLabel ?? "", coral, .leading)
            Spacer(minLength: 8)
            Image(systemName: "arrow.right").foregroundStyle(tertiary)
            Spacer(minLength: 8)
            role("TAKER", state.takerLabel ?? "", teal, .trailing)
          }
          Text([state.caption, "Tap to return"].compactMap { $0 }.joined(separator: " · "))
            .font(.footnote).foregroundStyle(tertiary)
        }
      } else {
        Text(state.ended ? "Session ended · \(state.round) rounds" : "Ready to spin · Tap to return")
          .font(.footnote).foregroundStyle(tertiary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(state.spoken)
  }

  private func role(_ title: String, _ label: String, _ color: Color, _ align: HorizontalAlignment) -> some View {
    VStack(alignment: align, spacing: 0) {
      Text(title).font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(color)
      Text(label).font(.title2.weight(.heavy)).lineLimit(1).minimumScaleFactor(0.6)
    }
  }
}

private struct CompactTrailing: View {
  let state: State

  var body: some View {
    Group {
      if state.hasRoles, let g = state.giverSeat, let t = state.takerSeat {
        (Text("\(g + 1)").foregroundColor(coral)
          + Text(" › ").foregroundColor(tertiary)
          + Text("\(t + 1)").foregroundColor(teal))
      } else {
        Text("R\(state.round)").foregroundColor(secondary)
      }
    }
    .font(.subheadline.weight(.heavy))
    .accessibilityLabel(state.spoken)
  }
}

/// Canvas `Logo.dc.html` in a 100-unit box: 8-dot ring, bottle at 45 degrees.
private struct LogoMark: View {
  var body: some View {
    GeometryReader { geo in
      let k = min(geo.size.width, geo.size.height) / 100
      ZStack {
        ForEach(0..<8, id: \.self) { i in
          // i = 0 is twelve o'clock, clockwise. 1 = neck side (taker), 5 = base side (giver).
          let a = Double(i) * .pi / 4
          Circle()
            .fill(i == 1 ? teal : (i == 5 ? coral : dot))
            .frame(width: (i == 1 || i == 5 ? 12.4 : 9.2) * k, height: (i == 1 || i == 5 ? 12.4 : 9.2) * k)
            .position(x: (50 + 36 * sin(a)) * k, y: (50 - 36 * cos(a)) * k)
        }
        BottleBody().fill(Color(red: 0xE8 / 255, green: 0xEE / 255, blue: 0xF7 / 255).opacity(0.95))
        BottlePart(rect: CGRect(x: -10, y: -100, width: 20, height: 12), radius: 4).fill(teal)
        BottlePart(rect: CGRect(x: -22, y: 70, width: 44, height: 14), radius: 6).fill(coral)
      }
    }
    .aspectRatio(1, contentMode: .fit)
    .accessibilityHidden(true)
  }
}

/// Maps bottle units (neck up, origin at the mark's centre) into the view: scale 0.27, rotate 45 degrees.
private func bottleTransform(_ rect: CGRect) -> CGAffineTransform {
  let k = min(rect.width, rect.height) / 100
  return CGAffineTransform(translationX: rect.midX, y: rect.midY)
    .rotated(by: .pi / 4)
    .scaledBy(x: 0.27 * k, y: 0.27 * k)
}

private struct BottleBody: Shape {
  func path(in rect: CGRect) -> Path {
    var p = Path()
    p.move(to: CGPoint(x: -8, y: -88))
    p.addLine(to: CGPoint(x: 8, y: -88))
    p.addLine(to: CGPoint(x: 8, y: -40))
    p.addCurve(to: CGPoint(x: 22, y: 0), control1: CGPoint(x: 8, y: -24), control2: CGPoint(x: 22, y: -18))
    p.addLine(to: CGPoint(x: 22, y: 72))
    p.addQuadCurve(to: CGPoint(x: 10, y: 84), control: CGPoint(x: 22, y: 84))
    p.addLine(to: CGPoint(x: -10, y: 84))
    p.addQuadCurve(to: CGPoint(x: -22, y: 72), control: CGPoint(x: -22, y: 84))
    p.addLine(to: CGPoint(x: -22, y: 0))
    p.addCurve(to: CGPoint(x: -8, y: -40), control1: CGPoint(x: -22, y: -18), control2: CGPoint(x: -8, y: -24))
    p.closeSubpath()
    return p.applying(bottleTransform(rect))
  }
}

private struct BottlePart: Shape {
  let rect: CGRect
  let radius: CGFloat

  func path(in bounds: CGRect) -> Path {
    Path(roundedRect: rect, cornerRadius: radius).applying(bottleTransform(bounds))
  }
}
```
What it renders (check against `docs/design/project/LiveActivity.dc.html` when the device pass happens):

| State | Lock Screen | Compact trailing | Expanded bottom |
|---|---|---|---|
| roles present, `revealed` | header + TAKER / GIVER tiles + "Tap to return to the game" | `giver › taker` numbers | GIVER → TAKER, "Tap to return" |
| roles present, `challenge` | same, footer "Truth · Tap to return to the game" | same | "Truth · Tap to return" |
| roles present, `ready` (last round) | same, footer "Last round: Truth · Tap to return to the game" | same | "Last round: Truth · Tap to return" |
| no roles, round 1 | "Session ready · N players" / "No rounds yet. Open to spin." | `R1` | "Ready to spin · Tap to return" |
| no roles, later round | "Round R · N players" / "Ready for the next spin." | `R<round>` | "Ready to spin · Tap to return" |
| ended | "Session ended · R rounds" | `R<round>` | "Session ended · R rounds" |

Leading compact and minimal are always the mark. Every region taps through to `spinfolk://session/<id>`.

---

## 3. Project file — `tool/add_widget_target.rb` (new, `chmod +x`)

```ruby
#!/usr/bin/env ruby
# One-shot and idempotent: wires the Phase 4 native files into
# ios/Runner.xcodeproj without the Xcode GUI.
#   - SpinfolkAttributes.swift, LiveActivityBridge.swift -> Runner
#   - new app-extension target SpinfolkWidget (SpinfolkLiveActivity.swift +
#     the shared SpinfolkAttributes.swift), embedded in Runner
# Run from the repo root:  ruby tool/add_widget_target.rb
require 'xcodeproj'

NAME = 'SpinfolkWidget'
project = Xcodeproj::Project.open(ARGV[0] || 'ios/Runner.xcodeproj')
runner = project.targets.find { |t| t.name == 'Runner' } or abort 'Runner target missing'
if project.targets.any? { |t| t.name == NAME }
  puts "#{NAME} already present, nothing to do"
  exit 0
end

native = project.main_group['Runner']['Native'] or abort 'Runner/Native group missing'
ref = lambda do |group, file|
  group.files.find { |f| f.path == file } || group.new_file(file)
end
attributes = ref.call(native, 'SpinfolkAttributes.swift')
bridge = ref.call(native, 'LiveActivityBridge.swift')
compiled = runner.source_build_phase.files_references
runner.add_file_references([attributes, bridge].reject { |f| compiled.include?(f) })

# Target, built by hand: Project#new_target would add a Foundation.framework
# reference and a Resources phase this extension does not need.
widget = project.new(Xcodeproj::Project::Object::PBXNativeTarget)
project.targets << widget
widget.name = NAME
widget.product_name = NAME
widget.product_type = Xcodeproj::Constants::PRODUCT_TYPE_UTI[:app_extension]
widget.product_reference = project.products_group.new_product_ref_for_target(NAME, :app_extension)
widget.build_phases << project.new(Xcodeproj::Project::Object::PBXSourcesBuildPhase)
widget.build_phases << project.new(Xcodeproj::Project::Object::PBXFrameworksBuildPhase)

# One configuration per Runner configuration (Debug, Release, Profile), on the
# same Flutter xcconfig so FLUTTER_BUILD_NAME / FLUTTER_BUILD_NUMBER resolve and
# the extension's version always equals the app's. No DEVELOPMENT_TEAM.
list = project.new(Xcodeproj::Project::Object::XCConfigurationList)
list.default_configuration_is_visible = '0'
list.default_configuration_name = 'Release'
runner.build_configurations.each do |rc|
  c = project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
  c.name = rc.name
  c.base_configuration_reference = rc.base_configuration_reference
  c.build_settings = {
    'APPLICATION_EXTENSION_API_ONLY' => 'YES',
    'CODE_SIGN_STYLE' => 'Automatic',
    'CURRENT_PROJECT_VERSION' => '$(FLUTTER_BUILD_NUMBER)',
    'GENERATE_INFOPLIST_FILE' => 'NO',
    'INFOPLIST_FILE' => "#{NAME}/Info.plist",
    'IPHONEOS_DEPLOYMENT_TARGET' => '17.0',
    'LD_RUNPATH_SEARCH_PATHS' => [
      '$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks'
    ],
    'MARKETING_VERSION' => '$(FLUTTER_BUILD_NAME)',
    'PRODUCT_BUNDLE_IDENTIFIER' => 'in.appamania.spinfolk.SpinfolkWidget',
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'SKIP_INSTALL' => 'YES',
    'SWIFT_VERSION' => '5.0',
    'TARGETED_DEVICE_FAMILY' => '1,2',
  }
  if rc.name == 'Debug'
    c.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG'
    c.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
  end
  list.build_configurations << c
end
widget.build_configuration_list = list

group = project.main_group.new_group(NAME, NAME)
widget.add_file_references([group.new_file('SpinfolkLiveActivity.swift'), attributes])
group.new_file('Info.plist') # referenced by INFOPLIST_FILE, member of no phase

# Embed in Runner. The phase must sit before Flutter's "Thin Binary" script,
# otherwise Xcode reports "Cycle inside Runner".
embed = runner.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
embed.add_file_reference(widget.product_reference, true).settings = {
  'ATTRIBUTES' => ['RemoveHeadersOnCopy']
}
thin = runner.build_phases.index { |p| p.display_name == 'Thin Binary' } or abort 'Thin Binary phase missing'
runner.build_phases.move(embed, thin)
runner.add_dependency(widget)

project.save
puts "added #{NAME}; Runner phases: #{runner.build_phases.map(&:display_name).join(' > ')}"
```
Run and check:
```sh
cp ios/Runner.xcodeproj/project.pbxproj /tmp/project.pbxproj.before
ruby tool/add_widget_target.rb
ruby tool/add_widget_target.rb                     # second run: "already present, nothing to do"
P=ios/Runner.xcodeproj/project.pbxproj
grep -c 'SpinfolkAttributes.swift' $P              # 6  (file ref, group child, 2 build files, 2 Sources entries)
grep -c 'LiveActivityBridge.swift' $P              # 4
grep -c 'SpinfolkLiveActivity.swift' $P            # 4
grep -c 'SpinfolkWidget/Info.plist' $P             # 3  (one per configuration)
grep -c 'in.appamania.spinfolk.SpinfolkWidget' $P  # 3
grep -c 'DEVELOPMENT_TEAM' $P                      # 0
grep -c 'XCLocalSwiftPackageReference' $P          # same number as in /tmp/project.pbxproj.before
xcodebuild -list -project ios/Runner.xcodeproj | sed -n '/Targets:/,/^$/p'   # Runner, RunnerTests, SpinfolkWidget
ruby -rxcodeproj -e '
  p = Xcodeproj::Project.open("ios/Runner.xcodeproj")
  w = p.targets.find { |t| t.name == "SpinfolkWidget" }
  r = p.targets.find { |t| t.name == "Runner" }
  puts r.build_phases.map(&:display_name).join(" > ")
  puts w.build_configurations.map { |c| "#{c.name}:#{c.base_configuration_reference&.path}" }.join(" ")
  puts w.source_build_phase.files_references.map(&:path).join(",")
  puts "widget packages: #{w.package_product_dependencies.size}"
'
```
Expected last block:
```
Run Script > Sources > Frameworks > Resources > Embed Frameworks > Embed Foundation Extensions > Thin Binary
Debug:Flutter/Debug.xcconfig Release:Flutter/Release.xcconfig Profile:Flutter/Release.xcconfig
SpinfolkLiveActivity.swift,SpinfolkAttributes.swift
widget packages: 0
```
(Phase 2b may have added phases to Runner; what matters is that "Embed Foundation Extensions" is immediately before "Thin Binary".)

What the script sets on the widget target, all three configurations: bundle id `in.appamania.spinfolk.SpinfolkWidget`; `IPHONEOS_DEPLOYMENT_TARGET 17.0`; `SWIFT_VERSION 5.0`; `INFOPLIST_FILE SpinfolkWidget/Info.plist`, `GENERATE_INFOPLIST_FILE NO`; `MARKETING_VERSION $(FLUTTER_BUILD_NAME)`, `CURRENT_PROJECT_VERSION $(FLUTTER_BUILD_NUMBER)` on Flutter's xcconfig (D2); `CODE_SIGN_STYLE Automatic` with no team (D4); `SKIP_INSTALL YES`; `APPLICATION_EXTENSION_API_ONLY YES`; extension run-path. It adds no package dependency, no framework reference, no Resources phase, no entitlements.

If something goes wrong: `cp /tmp/project.pbxproj.before ios/Runner.xcodeproj/project.pbxproj`, fix the cause, run again. Do not patch the generated project file by hand. The scheme `Runner.xcscheme` needs no change (Runner depends on the widget).

---

## 4. Build and inspect the bundle (no launch)

```sh
fvm flutter build ios --simulator --debug 2>&1 | tee /tmp/p4-build.log
grep -c 'Cycle inside' /tmp/p4-build.log           # 0
A=build/ios/iphonesimulator/Runner.app
ls $A/PlugIns/                                      # SpinfolkWidget.appex
for k in CFBundleShortVersionString CFBundleVersion CFBundleIdentifier MinimumOSVersion; do
  echo "$k app=$(/usr/libexec/PlistBuddy -c "Print :$k" $A/Info.plist) appex=$(/usr/libexec/PlistBuddy -c "Print :$k" $A/PlugIns/SpinfolkWidget.appex/Info.plist)"
done
/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionPointIdentifier' $A/PlugIns/SpinfolkWidget.appex/Info.plist
/usr/libexec/PlistBuddy -c 'Print :NSSupportsLiveActivities' -c 'Print :CFBundleURLTypes:0:CFBundleURLSchemes:0' $A/Info.plist
codesign -dv $A/PlugIns/SpinfolkWidget.appex 2>&1 | grep -E 'Identifier|Signature|TeamIdentifier'
```
Expected: versions and `MinimumOSVersion 17.0` equal on both sides; ids `in.appamania.spinfolk` and `in.appamania.spinfolk.SpinfolkWidget`; `com.apple.widgetkit-extension`; `true`; `spinfolk`; `Signature=adhoc`, `TeamIdentifier=not set`.

Build errors:
- "Cycle inside Runner": the embed phase is not before "Thin Binary"; restore the project file and re-run the script.
- "cannot find type 'SpinfolkAttributes'" in the widget: the shared file is not in the widget's Sources.
- "Multiple commands produce … Info.plist": `Info.plist` was added to a build phase; it must be referenced only by `INFOPLIST_FILE`.
- A signing error on the simulator build: someone set a team or a profile; remove it.

---

## 5. `NativeBridge` additions — `lib/platform/native_bridge.dart`

```dart
enum ActivityStatus { active, disabled, unsupported, error }

Stream<String> get sessionLinks;                       // validated session ids, broadcast
Future<void> linksReady();                             // 'url.ready'; never throws
Future<ActivityStatus> syncActivity(Map<String, Object?> payload);   // never throws
Future<void> endActivity(String sessionId, int rounds);              // never throws
Future<void> reconcileActivities(String? keepSessionId);             // never throws
```
- `syncActivity` → `invokeMapMethod<String, Object?>('activity.sync', payload)`; `state` mapped by enum name, anything unknown → `error`; `MissingPluginException` → `unsupported`; `PlatformException` → `error`.
- `endActivity` → `'activity.end'` with `{'sessionId': …, 'rounds': …}`; `reconcileActivities` → `'activity.reconcile'` with `{'sessionId': keepSessionId}`. Both swallow the two exception types.
- `_onCall` gains `url.open`: the argument must be a `Map` whose `sessionId` is a `String` matching `^[0-9a-f]{32}$`; then add it to `sessionLinks`. Otherwise ignore (D7).
- `dispose` also closes the new controller.

Extend `test/native_bridge_test.dart`: argument maps for the three `activity.*` calls; each `state` string → enum; unknown state and a null result → `error`; no handler → `unsupported`; `PlatformException` → `error`; `url.open` with a valid id reaches the stream; uppercase hex, 31 characters, a path-like string, a missing key and a non-map are dropped; `linksReady` sends `url.ready` and does not throw without a handler.

Extend `test/support/fake_native.dart`: `String activityState = 'active'`; handler returns `{'state': activityState}` for `activity.sync`, `{'ok': true}` for `activity.end`, `{'ended': 0}` for `activity.reconcile`, `null` for `url.ready`.

---

## 6. `LiveActivitySync` — `lib/platform/live_activity_sync.dart`

```dart
/// Pure. The `activity.sync` arguments for a session that is not spinning.
/// [last] is Phase 2b's last logged round (type as 2b defines it), used only in phase ready.
Map<String, Object?> activityPayload(Session session, {/* 2b last-round type */ last});

@lazySingleton
class LiveActivitySync {
  LiveActivitySync(this._bloc, this._bridge, this._settings);

  void start();            // idempotent; called once from main
  void foreground();       // launch and every onResume
  @disposeMethod
  Future<void> dispose();
}
```
`activityPayload` — always `sessionId`, `startedAt` (`startedAtMs`), `players` (`playerCount`), `round`, `phase` (`phase.name`). Roles per the table in `prd.md` §6: `taker`, `giver` (0-based ints), `takerLabel`, `giverLabel` (`displayLabel(session.players[seat])`), `mode` (`mode.name`). Absent keys are omitted, not sent as null. In `ready`, use the last round only if it ended with a mode and both seats are `< playerCount`.

Private state: `Session? _known` (last session seen while not spinning), `String? _sent` (`jsonEncode` of the last payload sent), `Future<void> _tail = Future.value()` (serial chain, D9), two subscriptions.

`_enqueue(Future<void> Function() op)`: `_tail = _tail.then((_) => op()).catchError((_) {});`

On each bloc state:
1. If it is the active state and spinning → return.
2. `session = _sessionOf(state)`.
3. `session == null`: if `_known != null` → enqueue `endActivity(_known.id, _known.round)`; clear `_known` and `_sent`. Return. (A loading state is ignored: return without clearing.)
4. If `_known != null && _known.id != session.id` → enqueue `endActivity(_known.id, _known.round)` and clear `_sent`.
5. `_known = session`; `encoded = jsonEncode(activityPayload(...))`; if `encoded == _sent` return; `_sent = encoded`; enqueue: `status = await _bridge.syncActivity(payload); _settings.activityStatusChanged(status);`.

`foreground()`: enqueue `reconcileActivities(_sessionOf(_bloc.state)?.id)`; then set `_sent = null` and run the state handler on `_bloc.state` (forces a re-sync; a no-op while spinning or without a session).

`start()`:
1. `sessionLinks.listen((id) => _bloc.add(SessionLinkOpened(id)))`, then `_bridge.linksReady()` — subscribe first, so a held cold-start link is not lost.
2. `foreground()`.
3. `_bloc.stream.listen(<state handler>)`.

No `BuildContext`, no repository, no navigation, no timers. Gameplay never awaits anything here.

### `test/live_activity_sync_test.dart`
Real `SessionBloc` on `FakeSessionRepository` with `Random(1)`, real `NativeBridge` on `FakeNative`, real `SettingsCubit`. `settle() => pumpEventQueue()`.
- `activityPayload` exact-map expectations for each row of P4-7 (include a named player: label `Riya · P1`, seat 0).
- Start a session → calls are exactly `[url.ready, activity.reconcile {sessionId: null}, activity.sync {… phase: ready}]`.
- `SpinRequested` → no new `activity.*` call while spinning. `SpinAnimationFinished` → one `activity.sync` with `phase: revealed` and both labels.
- Same with `AppBackgrounded` instead of the finished event → one sync.
- `ModeChosen` → sync with `mode`. Next round → sync with the round number raised (and last-round roles, per 2b's state). `ReplayRequested` and a failed write → no call.
- Players edited → sync with the new `players`.
- End → `activity.end {sessionId: 'test', rounds: <log.length>}`, and no sync after it.
- Session id changes without a gap (if 2b allows it) → `activity.end` for the old id, then `activity.sync` for the new one, in that order.
- Stored session at launch → `activity.reconcile {sessionId: 'test'}` then `activity.sync`.
- `foreground()` again → another reconcile + sync even though the payload is unchanged; while spinning → reconcile only.
- `activityState = 'disabled'` → `settings.state.activityStatus == ActivityStatus.disabled`; handler throwing → `error`; nothing escapes.
- `send('url.open', {'sessionId': <stored id as 32 hex>})` before resume → bloc reaches the active state. Use a 32-hex id in the stored fixture for this test.
- Order: with a slow fake (`await Future.delayed`) the recorded call order still equals the enqueue order.

---

## 7. `SettingsCubit` and the sheet

- `SettingsState` gains `final ActivityStatus? activityStatus;` (in `==` / `hashCode`, carried through every explicit rebuild) and `bool get lockScreenOff => activityStatus == ActivityStatus.disabled || activityStatus == ActivityStatus.unsupported;`.
- `void activityStatusChanged(ActivityStatus status)` — emit only when it differs.
- Sheet: directly under the SESSION card, when `lockScreenOff`, one footnote-style line (13, `textTertiary`, same inset as the other footnotes): `Lock Screen updates are off in iOS Settings.` No button, no icon, not shown for `error` or `active`.

Tests: `settings_cubit_test` — status changes are emitted once, `lockScreenOff` truth table. `game_flow_test` — with `native.activityState = 'disabled'` the sheet shows the line; default → not found; a full loop still completes with the disabled status (gameplay unaffected). `layout_test` — the sheet visit with the line present.

---

## 8. Wiring

- `lib/app/app.dart`: the existing `AppLifecycleListener` gets `onResume: () => getIt<LiveActivitySync>().foreground(),`.
- `lib/main.dart`, after the first non-loading session state is awaited and next to `getIt<Announcer>().start()`:
  ```dart
  getIt<LiveActivitySync>().start();
  ```
  It must run after the first state so the launch reconcile uses the real session id, and before `runApp` so a cold-start link resumes the session before the first frame.
- `test/support/harness.dart`: register `LiveActivitySync` (singleton), call `start()`, dispose in tear-down.
- Router: no change. A link never becomes a location; the redirect reacts to the state the bloc reaches. Add one `game_flow_test` case: stored session, `pumpApp`, `native.send('url.open', {'sessionId': id})`, pump → the game screen is shown (pill text found), not Home.

---

## 9. Rules and verify

`tool/check_rules.sh`, before the final echo:
```sh
grep -q 'DEVELOPMENT_TEAM' ios/Runner.xcodeproj/project.pbxproj && bad 'no team id in the repo'
```

Verify (paste the output of each):
```sh
fvm dart run build_runner build --delete-conflicting-outputs
fvm dart format --set-exit-if-changed .
fvm flutter analyze
tool/check_rules.sh
fvm flutter test
fvm flutter build ios --simulator --debug          # then the inspection block of §4 again
git diff phase-3 --stat -- pubspec.yaml pubspec.lock        # must print nothing
find ios -name Podfile -o -name '*.entitlements' | grep -v '/Flutter/ephemeral/'   # must print nothing
grep -rn "BuildContext\|sqflite\|repository" lib/platform/live_activity_sync.dart   # must print nothing
git status --short ios/                                      # Info.plist, SceneDelegate, Native/*, SpinfolkWidget/*, project.pbxproj only
```

**Suggested commits:** `Phase 4: widget extension target and ActivityKit bridge` (after step 4) · `Phase 4: live activity sync, session links, status line` (after step 8). Evidence folders are ignored and stay out of every commit.

---

## 10. Deferred device flows (write, do not run)

Both files start with `# DEFERRED: run in the post-Phase-5 device pass. Not executed in Phase 4.` ⟨start a game⟩ stands for Phase 2b's steps from launch to a running game.

### `tool/maestro/phase4.yaml`
```yaml
# DEFERRED: run in the post-Phase-5 device pass. Not executed in Phase 4.
appId: in.appamania.spinfolk
---
- launchApp: { clearState: true }
# ⟨start a game⟩                       -> P4-D1: activity appears (one-line card)
- tapOn: "Spin"
- extendedWaitUntil: { visible: "Taker .*", timeout: 15000 }     # P4-D2: tiles now, not before
- tapOn: "Truth"
- tapOn: "Session and settings"
- assertNotVisible: "Lock Screen updates are off in iOS Settings."
- tapOn: "Done"
- pressKey: Home                         # island shows compact content (P4-D3)
- takeScreenshot: docs/plans/phase-4/evidence/p4-island-compact
```

### `tool/phase4_gate.sh` (`chmod +x`)
```sh
#!/usr/bin/env bash
# DEFERRED: run in the post-Phase-5 device pass. Not executed in Phase 4.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SIM:?set SIM to a booted simulator UDID (a Dynamic Island model)}"
APP=in.appamania.spinfolk
EVID=docs/plans/phase-4/evidence; mkdir -p "$EVID"      # git-ignored
fvm flutter build ios --simulator --debug
xcrun simctl uninstall "$SIM" "$APP" || true
xcrun simctl install "$SIM" build/ios/iphonesimulator/Runner.app
~/.maestro/bin/maestro --device "$SIM" test tool/maestro/phase4.yaml
DB=$(find "$(xcrun simctl get_app_container "$SIM" "$APP" data)" -name spinfolk.db | head -1)
ID=$(sqlite3 "$DB" 'SELECT id FROM session;')            # re-check the table name against schema v2
# P4-D4 warm: app is in the background after the flow.
xcrun simctl openurl "$SIM" "spinfolk://session/$ID"; sleep 2
xcrun simctl io "$SIM" screenshot "$EVID/p4-link-warm.png"        # game screen, same round
# P4-D4 cold.
xcrun simctl terminate "$SIM" "$APP"
xcrun simctl openurl "$SIM" "spinfolk://session/$ID"; sleep 4
xcrun simctl io "$SIM" screenshot "$EVID/p4-link-cold.png"        # game screen, not Home
# Foreign id must be ignored.
xcrun simctl openurl "$SIM" "spinfolk://session/00000000000000000000000000000000"; sleep 2
xcrun simctl io "$SIM" screenshot "$EVID/p4-link-foreign.png"     # unchanged
```
Manual part, to list in the report as a numbered script with expected results: lock the simulator (Device → Lock) and screenshot the Lock Screen in each phase (P4-D3); long-press the island for the expanded view; End Session → activity gone at once (P4-D5); kill and relaunch → exactly one activity (P4-D6); iOS Settings → Spinfolk → Live Activities off → play a round, open the sheet, see the line (P4-D7).

---

## 11. Report format

1. What works.
2. P4-1 … P4-11: PASS / FAIL with real command output (script output, greps, bundle inspection). P4-D1 … P4-D8: **NOT VERIFIED (deferred by owner decision; D8 also blocked on the team id)**, plus the manual script.
3. The reconcile table of §0, filled in.
4. Every change made to the Swift or the Ruby given here, with the compiler message or reason.
5. Deviations from this file. Deviations from `LiveActivity.dc.html`.
6. Open questions from `prd.md` §9 still unanswered.
7. Next step (Phase 5): full device pass over the deferred flows of Phases 2b–4, app icon, README, release audit, signing with the owner's team id, TestFlight.
