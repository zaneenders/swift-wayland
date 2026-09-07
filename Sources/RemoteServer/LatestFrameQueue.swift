/// One in-flight snapshot and one replaceable pending snapshot. Input events
/// must never pass through this queue: only immutable visual snapshots belong here.
@MainActor
final class LatestFrameQueue<Snapshot> {
  private(set) var isBusy = false
  private var pending: Snapshot?

  /// Returns work to start immediately, or replaces the waiting snapshot.
  func submit(_ snapshot: Snapshot) -> Snapshot? {
    guard !isBusy else {
      pending = snapshot
      return nil
    }
    isBusy = true
    return snapshot
  }

  /// Called only after the current encode AND transport write have finished.
  func complete() -> Snapshot? {
    if let next = pending {
      pending = nil
      return next
    }
    isBusy = false
    return nil
  }

  func discardPending() {
    pending = nil
  }
}
