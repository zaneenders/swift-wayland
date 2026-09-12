import Dispatch
import Observation
import Synchronization

// The synchronous tracking API delivers a cancellation event on mutation, not
// an externally owned token. Release callback captures immediately on reset;
// any remaining registration cancels itself when its dependency next changes.
private final class FrameTrackingSubscription: Sendable {
  private let callback: Mutex<(@MainActor @Sendable () -> Void)?>

  init(_ onChange: @escaping @MainActor @Sendable () -> Void) {
    callback = Mutex(onChange)
  }

  func cancel() {
    callback.withLock { $0 = nil }
  }

  func takeCallback() -> (@MainActor @Sendable () -> Void)? {
    callback.withLock { callback in
      defer { callback = nil }
      return callback
    }
  }
}

/// Shared graph evaluation. Backends retain ownership of scheduling and presentation.
@MainActor
package final class FrameProducer {
  private var generation: UInt64 = 0
  private var subscription: FrameTrackingSubscription?

  package init() {}

  /// Releases callbacks and discards invalidations from the previous frame or session.
  package func reset() {
    generation &+= 1
    subscription?.cancel()
    subscription = nil
  }

  deinit { subscription?.cancel() }

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
    let subscription = FrameTrackingSubscription(onChange)
    self.subscription = subscription
    // Refresh dependencies for every frame, including input/viewport-only frames.
    let drawList = withObservationTracking(options: .didSet) {
      var drawList = DrawList()
      if let content {
        BlockEngine.draw(
          content, into: &drawList, in: Rect(origin: .zero, size: viewport), context: context)
      }
      return drawList
    } onChange: { [weak self, weak subscription] event in
      event.cancel()
      guard let onChange = subscription?.takeCallback() else { return }
      // Keep rendering backend-driven and coalesce changes until the next frame.
      DispatchQueue.main.async { [weak self] in
        guard let self, self.generation == generation else { return }
        onChange()
      }
    }
    interaction.endFrame()
    return drawList
  }
}
