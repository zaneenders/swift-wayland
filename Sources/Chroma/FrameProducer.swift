import Dispatch
import Observation

/// Shared graph evaluation. Backends retain ownership of scheduling and presentation.
@MainActor
package final class FrameProducer {
  private var generation: UInt64 = 0

  package init() {}

  /// Discards callbacks belonging to replaced content or a finished session.
  package func reset() {
    generation &+= 1
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
    let drawList = withObservationTracking {
      var drawList = DrawList()
      if let content {
        BlockEngine.draw(
          content, into: &drawList, in: Rect(origin: .zero, size: viewport), context: context)
      }
      return drawList
    } onChange: { [weak self] in
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
