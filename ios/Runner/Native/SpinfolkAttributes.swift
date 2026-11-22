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
