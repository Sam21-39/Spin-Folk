import AVFoundation
import UIKit

/// AVSpeechSynthesizer behind the spinfolk/native channel. Main thread only.
final class SpeechBridge: NSObject, AVSpeechSynthesizerDelegate {
  /// "done" | "cancelled" | "error"
  var onEvent: ((String) -> Void)?

  private let synth = AVSpeechSynthesizer()
  private var current: AVSpeechUtterance?
  private var interrupted = false
  /// Deactivating inside the delegate callback fails with "session busy" while
  /// the synthesizer still holds the output, which leaves other audio ducked.
  /// Tune on a real device.
  private let deactivateDelay: TimeInterval = 0.3

  override init() {
    super.init()
    synth.delegate = self
    let nc = NotificationCenter.default
    nc.addObserver(self, selector: #selector(didEnterBackground),
                   name: UIApplication.didEnterBackgroundNotification, object: nil)
    nc.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] n in
      self?.interruption(n)
    }
  }

  func speak(text: String, voiceId: String?, rate: Double) throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
    try session.setActive(true)
    let u = AVSpeechUtterance(string: text)
    u.voice = voiceId.flatMap(AVSpeechSynthesisVoice.init(identifier:))
      ?? AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
    u.rate = Float(min(max(rate, Double(AVSpeechUtteranceMinimumSpeechRate)),
                       Double(AVSpeechUtteranceMaximumSpeechRate)))
    // Replacing: `current` moves first, so the old utterance's didCancel is ignored.
    interrupted = false
    current = u
    synth.stopSpeaking(at: .immediate)
    synth.speak(u)
  }

  func stop() {
    synth.stopSpeaking(at: .immediate)
  }

  func voices(language: String) -> [[String: String]] {
    let prefix = language.lowercased()
    return AVSpeechSynthesisVoice.speechVoices()
      .filter { v in
        guard v.language.lowercased().hasPrefix(prefix), !v.voiceTraits.contains(.isNoveltyVoice) else { return false }
        if #available(iOS 17.0, *) { return !v.voiceTraits.contains(.isPersonalVoice) }
        return true
      }
      .map {
        ["id": $0.identifier, "name": $0.name, "language": $0.language,
         "quality": $0.quality == .premium ? "premium" : ($0.quality == .enhanced ? "enhanced" : "default")]
      }
  }

  private func finish(_ utterance: AVSpeechUtterance, _ state: String) {
    guard Thread.isMainThread else {
      DispatchQueue.main.async { self.finish(utterance, state) }
      return
    }
    guard utterance === current else { return }
    current = nil
    DispatchQueue.main.asyncAfter(deadline: .now() + deactivateDelay) { [weak self] in
      guard let self, self.current == nil else { return }  // a new line started meanwhile
      try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    onEvent?(interrupted ? "error" : state)
    interrupted = false
  }

  func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    finish(utterance, "done")
  }

  func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
    finish(utterance, "cancelled")
  }

  @objc private func didEnterBackground() {
    stop()
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  private func interruption(_ note: Notification) {
    guard current != nil,
          let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
          AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
    interrupted = true
    stop()
  }
}
