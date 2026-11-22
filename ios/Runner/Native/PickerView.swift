import Flutter
import SwiftUI
import UIKit

@Observable
final class PickerModel {
  var min = 2
  var max = 60
  var value = 8
  var onChange: ((Int) -> Void)?
  /// Stale-config rule: values sent to Dart since the last config that matched our latest sent value.
  /// A config whose value is in this set but is not the latest sent is an echo of a superseded
  /// scroll position, so it is skipped (no jitter). Any other value (e.g. End Session -> 2) is
  /// a real Dart force and is applied. A config equal to the latest sent value is an ack: clears the set.
  var sent: [Int] = []

  /// Ignores malformed input; clamps value into min...max. Never echoes to Dart.
  func apply(_ args: Any?) {
    guard let d = args as? [String: Any] else { return }
    let newMin = (d["min"] as? Int) ?? min
    let newMax = (d["max"] as? Int) ?? max
    guard newMin <= newMax else { return }
    let newValue = Swift.min(Swift.max((d["value"] as? Int) ?? value, newMin), newMax)
    if newMin != min { min = newMin }
    if newMax != max { max = newMax }
    if d["value"] != nil {
      if newValue == sent.last {
        sent.removeAll()
      } else if sent.contains(newValue) {
        return
      } else {
        sent.removeAll()
      }
    }
    if newValue != value { value = newValue }
  }
}

struct PickerIsland: View {
  let model: PickerModel

  var body: some View {
    Picker("Number of players", selection: Binding(
      get: { model.value },
      set: { v in
        guard v != model.value else { return }
        model.value = v
        model.sent.append(v)
        model.onChange?(v)
      }
    )) {
      ForEach(model.min...model.max, id: \.self) { Text("\($0) players").tag($0) }
    }
    .pickerStyle(.wheel)
    .fontDesign(.rounded)
    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .glassBackground(RoundedRectangle(cornerRadius: 28, style: .continuous))
  }
}

final class PickerPlatformView: NSObject, FlutterPlatformView {
  private let channel: FlutterMethodChannel
  private let model = PickerModel()
  private let host: UIHostingController<PickerIsland>

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "spinfolk/picker/\(viewId)", binaryMessenger: messenger)
    model.apply(args)
    host = UIHostingController(rootView: PickerIsland(model: model))
    host.view.backgroundColor = .clear
    host.view.isOpaque = false
    host.safeAreaRegions = []
    host.view.frame = frame
    super.init()
    model.onChange = { [weak self] v in
      self?.channel.invokeMethod("changed", arguments: ["value": v])
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

final class PickerFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    PickerPlatformView(frame: frame, viewId: viewId, args: args, messenger: messenger)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}
