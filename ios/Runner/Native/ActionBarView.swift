import Flutter
import SwiftUI
import UIKit

struct ActionItem: Identifiable, Equatable {
  let id: String
  let label: String
  let style: String
  let enabled: Bool
}

@Observable
final class ActionBarModel {
  var items: [ActionItem] = []
  var layout = "stack"
  var onTap: ((String) -> Void)?

  func apply(_ args: Any?) {
    guard let d = args as? [String: Any] else { return }
    if let raw = d["items"] as? [Any] {
      let parsed: [ActionItem] = raw.compactMap { e in
        guard let m = e as? [String: Any],
              let id = m["id"] as? String,
              let label = m["label"] as? String else { return nil }
        let style = m["style"] as? String ?? "secondary"
        let known = ["primary", "secondary", "destructive", "choice"]
        return ActionItem(
          id: id, label: label,
          style: known.contains(style) ? style : "secondary",
          enabled: m["enabled"] as? Bool ?? true)
      }
      // Duplicate ids break ForEach identity; drop the whole config.
      if Set(parsed.map(\.id)).count == parsed.count, parsed != items { items = parsed }
    }
    let newLayout = (d["layout"] as? String) == "row" ? "row" : "stack"
    if newLayout != layout { layout = newLayout }
  }
}

private let coral = Color(red: 1.0, green: 0x7A / 255, blue: 0x59 / 255)

struct ActionBarIsland: View {
  let model: ActionBarModel

  var body: some View {
    let layout = model.layout == "row"
      ? AnyLayout(HStackLayout(spacing: 12))
      : AnyLayout(VStackLayout(spacing: 10))
    Group {
      if #available(iOS 26.0, *) {
        GlassEffectContainer(spacing: 10) { content(layout) }
      } else {
        content(layout)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    .fontDesign(.rounded)
    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
  }

  private func content(_ layout: AnyLayout) -> some View {
    layout {
      ForEach(model.items) { item in
        button(item)
      }
    }
  }

  @ViewBuilder
  private func button(_ item: ActionItem) -> some View {
    let b = Button { model.onTap?(item.id) } label: {
      Text(item.label)
        .font(.headline)
        .frame(maxWidth: .infinity, minHeight: item.style == "primary" ? 64 : 50)
    }
    .disabled(!item.enabled)
    .buttonBorderShape(.capsule)
    .foregroundStyle(item.style == "destructive" ? coral : Color.white)

    if #available(iOS 26.0, *) {
      if item.style == "primary" {
        b.buttonStyle(.glassProminent).tint(.white.opacity(0.2))
      } else {
        b.buttonStyle(.glass)
      }
    } else {
      b.buttonStyle(.plain)
        .background(.ultraThinMaterial, in: Capsule())
        .contentShape(Capsule())
    }
  }
}

final class ActionBarPlatformView: NSObject, FlutterPlatformView {
  private let channel: FlutterMethodChannel
  private let model = ActionBarModel()
  private let host: UIHostingController<ActionBarIsland>

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "spinfolk/actionbar/\(viewId)", binaryMessenger: messenger)
    model.apply(args)
    host = UIHostingController(rootView: ActionBarIsland(model: model))
    host.view.backgroundColor = .clear
    host.view.isOpaque = false
    host.safeAreaRegions = []
    host.view.frame = frame
    super.init()
    model.onTap = { [weak self] id in
      self?.channel.invokeMethod("tap", arguments: ["id": id])
    }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(nil) }
      if call.method == "config" {
        self.model.apply(call.arguments)
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { host.view }

  deinit { channel.setMethodCallHandler(nil) }
}

final class ActionBarFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    ActionBarPlatformView(frame: frame, viewId: viewId, args: args, messenger: messenger)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}
