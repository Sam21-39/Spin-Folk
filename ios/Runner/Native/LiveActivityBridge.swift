import ActivityKit
import Foundation
import UIKit

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
    if UIDevice.current.userInterfaceIdiom == .pad { return ["state": "unsupported"] }
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
    if UIDevice.current.userInterfaceIdiom == .pad { return 0 }
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
