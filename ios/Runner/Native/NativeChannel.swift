import Flutter
import Foundation

/// Owner of the shared spinfolk/native channel. Main thread only.
/// Phase 4 adds activity.* and url.* here.
final class NativeChannel {
  static let shared = NativeChannel()

  private var channel: FlutterMethodChannel?
  private let speech = SpeechBridge()

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
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
