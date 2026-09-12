import Dispatch
import Observation
import Synchronization

// Swift 6.3 compatibility: cancel one-shot tracking through an observed token,
// using only public APIs. Keep this path when building with newer compilers too.
//
// Swift 6.4 migration candidate (see stdlib Observation/ContinuousObservation.swift):
// withContinuousObservation returns an ObservationTracking.Token whose cancel()
// or destruction retires tracking. It also owns reevaluation scheduling, so it
// is not a drop-in replacement for this synchronous, backend-driven frame API.
// Before adopting it, preserve dependency refresh on input/viewport-only frames,
// post-setter delivery, and cancellation of stale callbacks; run the observation
// lifetime tests against both paths. The options-based withObservationTracking
// overload alone does not return an externally owned cancellation token.
//
// A future conditional path needs #if compiler(>=6.4) for API visibility AND the
// SDK's runtime availability check for deployment targets predating those APIs.
// Do not select it using #if swift(>=6.4): that checks language mode, not compiler
// capability. Until that migration is validated, use the 6.3 path everywhere.
@MainActor
@Observable
private final class FrameTrackingToken {
  var revision: UInt64 = 0
}

private final class FrameTrackingSubscription: Sendable {
  private let active = Mutex(true)

  func cancel() {
    active.withLock { $0 = false }
  }

  func claimChange() -> Bool {
    active.withLock { active in
      guard active else { return false }
      active = false
      return true
    }
  }
}

/// Shared graph evaluation. Backends retain ownership of scheduling and presentation.
@MainActor
package final class FrameProducer {
  private var generation: UInt64 = 0
  private let trackingToken = FrameTrackingToken()
  private var subscription: FrameTrackingSubscription?

  package init() {}

  /// Cancels tracking and discards callbacks from the previous frame or session.
  package func reset() {
    generation &+= 1
    subscription?.cancel()
    subscription = nil
    // Swift 6.3's public tracking API has no cancellation handle. Every frame
    // reads this token so changing it retires the old one-shot registration.
    // Disable its callback first: cancellation must not schedule a redraw.
    trackingToken.revision &+= 1
  }

  package func render(
    content: (any Block)?,
    viewport: Size,
    input: InputState,
    context: RenderContext,
    onChange: @escaping @MainActor @Sendable () -> Void
  ) -> DrawList {
    reset()
    let generation = generation
    let interaction = context.interaction
    // Command routing may mutate models. Do it before collecting drawing dependencies.
    interaction.beginFrame(input: input)
    let subscription = FrameTrackingSubscription()
    self.subscription = subscription
    let drawList = withObservationTracking {
      _ = trackingToken.revision
      var drawList = DrawList()
      if let content {
        BlockEngine.draw(
          content, into: &drawList, in: Rect(origin: .zero, size: viewport), context: context)
      }
      return drawList
    } onChange: { [weak self] in
      guard subscription.claimChange() else { return }
      // Observation fires before the setter completes. Never render synchronously here.
      // One-shot tracking coalesces mutations until the next evaluation rearms it.
      DispatchQueue.main.async { [weak self] in
        guard let self, self.generation == generation else { return }
        onChange()
      }
    }
    interaction.endFrame()
    return drawList
  }
}
