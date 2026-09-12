import Foundation

/// Checked by the existing presentation timer, so disconnects need no extra timer cleanup.
enum FrameResponseDeadline {
  static let timeout: TimeInterval = 10

  static func hasExpired(
    since started: TimeInterval, now: TimeInterval = ProcessInfo.processInfo.systemUptime
  ) -> Bool {
    now - started >= timeout
  }
}
