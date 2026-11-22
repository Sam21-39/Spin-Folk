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
    guard url.scheme == "spinfolk", url.host == "session",
          url.pathComponents.count == 2, url.pathComponents[0] == "/" else { return }
    let id = url.pathComponents[1]
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
