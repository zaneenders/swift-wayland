import Logging
import ShapeTree

let defaultScale: UInt = 1

@MainActor
extension Wayland {
  public static func renderLayout(_ block: some Block, layout: Layout, logLevel: Logger.Level = .warning) {
    var renderer = RenderWalker(
      positions: layout.positions,
      sizes: layout.sizes,
      Self.self,
      logLevel: logLevel
    )
    block.walk(with: &renderer)
  }

  public static func calculateLayout(_ block: some Block, height: UInt, width: UInt, settings: FontMetrics) -> Layout {
    return ShapeTree.calculateLayout(block, height: height, width: width, settings: settings)
  }

  public static func render(
    _ block: some Block, height: UInt, width: UInt, settings: FontMetrics, logLevel: Logger.Level = .warning
  ) {
    let layout = calculateLayout(block, height: height, width: width, settings: settings)
    renderLayout(block, layout: layout, logLevel: logLevel)
  }
}

struct RenderWalker: Walker {
  var currentId: Hash = 0
  var parentId: Hash = 0
  let logger: Logger
  private var positions: [Hash: (x: UInt, y: UInt)] = [:]
  private var sizes: [Hash: Container]
  private let drawer: Renderer.Type

  init(
    positions: [Hash: (x: UInt, y: UInt)],
    sizes: [Hash: Container],
    _ drawer: any Renderer.Type,
    logLevel: Logger.Level
  ) {
    self.positions = positions
    self.sizes = sizes
    self.drawer = drawer
    self.logger = Logger.create(logLevel: logLevel)
  }

  mutating func before(_ block: some Block) {
    guard let pos = positions[currentId] else {
      logger.warning("No position for \(currentId)")
      return
    }

    if let attributedBlock = block as? any HasAttributes,
      let word = attributedBlock.layer as? Text
    {
      let scale = attributedBlock.attributes.scale ?? defaultScale
      let foreground = attributedBlock.attributes.foreground ?? .white
      let background = attributedBlock.attributes.background ?? .black
      let padding = attributedBlock.attributes.padding ?? Padding()
      let px = padding.left ?? 0
      let py = padding.top ?? 0
      drawer.drawText(
        word.draw(at: (pos.y + py, pos.x + px), scale: scale, foreground: foreground, background: background))
      return
    }

    if let word = block as? Text {
      drawer.drawText(word.draw(at: (pos.y, pos.x)))
      return
    }

    if let attributedBlock = block as? any HasAttributes,
      let size = sizes[currentId]
    {
      let padding = attributedBlock.attributes.padding ?? Padding()
      let px = padding.left ?? 0
      let py = padding.top ?? 0
      let quad = RenderableQuad(
        dst_p0: (pos.x + px, pos.y + py),
        dst_p1: (pos.x + px + size.width, pos.y + py + size.height),
        tex_tl: (0, 0),
        tex_br: (1, 1),
        color: attributedBlock.attributes.background ?? .white,
        borderColor: attributedBlock.attributes.borderColor ?? .black,
        borderWidth: Float(attributedBlock.attributes.borderWidth ?? 0),
        cornerRadius: Float(attributedBlock.attributes.borderRadius ?? 0)
      )
      drawer.drawQuad(quad)
      return
    }
  }

  mutating func after(_ block: some Block) {}
  mutating func before(child block: some Block) {}
  mutating func after(child block: some Block) {}
}
