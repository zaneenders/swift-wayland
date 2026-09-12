import Chroma

public struct HeadlessFrame: Equatable, Sendable {
  public let viewport: Size
  public let commands: [DrawCommand]

  public init(viewport: Size, commands: [DrawCommand]) {
    self.viewport = viewport
    self.commands = commands
  }
}

@MainActor
public final class HeadlessRenderer: Renderer {
  public let name = "Headless"

  public var content: (any Block)? {
    didSet { frameProducer.reset() }
  }
  private let frameProducer = FrameProducer()

  /// Called after an observed model changes. Rendering remains explicitly driven by the caller.
  public var onRedrawRequested: (@MainActor () -> Void)?
  public var frameObserver: FrameObserver?
  public var onClose: (() -> Void)?
  public var viewport: Size

  public private(set) var title: String?
  public private(set) var lastFrame: HeadlessFrame?

  package let interaction = Interaction()

  public init(size: Size = Size(width: 800, height: 600)) {
    self.viewport = size
  }

  /// Runs a single frame. Unlike a windowed backend, this method does not start
  /// an event loop.
  public func run(title: String) {
    self.title = title
    _ = render()
  }

  /// Evaluates `content` for one frame using the supplied input snapshot.
  ///
  /// Calling this repeatedly drives pointer, keyboard, scrolling, and text-input
  /// behavior while retaining focus and interaction state between calls.
  @discardableResult
  public func render(input: InputState = InputState()) -> HeadlessFrame {
    let drawList = frameProducer.render(
      content: content, viewport: viewport, input: input, context: context,
      onChange: { [weak self] in self?.onRedrawRequested?() })
    _ = interaction.consumeRedrawRequest()
    frameObserver?(FrameObservation(drawList: drawList, viewport: viewport))

    let frame = HeadlessFrame(viewport: viewport, commands: drawList.commands)
    lastFrame = frame
    return frame
  }

  /// Invokes the same close callback used by windowed renderers.
  public func close() {
    frameProducer.reset()
    onClose?()
  }
}
