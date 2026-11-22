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
  var roundsText: String { "\(round) \(round == 1 ? "round" : "rounds")" }
  var summary: String { "Round \(round) · \(players) players" }
  /// In `ready` the roles are the previous round's (from the round log).
  var caption: String? {
    if phase == "ready" { return hasRoles ? "Last round: \(modeText ?? "Pass")" : nil }
    return modeText
  }
  var spoken: String {
    if ended { return "Session ended, \(roundsText)" }
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
    if state.ended { return "Session ended · \(state.roundsText)" }
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
        Text(state.ended ? "Session ended · \(state.roundsText)" : "Ready to spin · Tap to return")
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
