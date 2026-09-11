/// A complete produced frame, before backend culling. This is a display-list
/// snapshot, not a serializable Block graph or a guarantee of presentation.
public struct FrameObservation: Sendable {
  public let drawList: DrawList
  public let viewport: Size
  /// Nil for producers without a raster target (headless and remote server).
  public let rasterScale: Point?

  public init(drawList: DrawList, viewport: Size, rasterScale: Point? = nil) {
    self.drawList = drawList
    self.viewport = viewport
    self.rasterScale = rasterScale
  }
}

/// Invoked synchronously on the main actor after interaction completion.
/// Keep callbacks short: retain a snapshot and move encoding/I/O to a worker.
/// Consumers own activation, shortcuts, environment policy and storage limits.
public typealias FrameObserver = @MainActor (FrameObservation) -> Void
