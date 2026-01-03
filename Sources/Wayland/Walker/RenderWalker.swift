import Logging

let defaultScale: UInt = 1

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
    if let pos = positions[currentId] {
      if let attributedBlock = block as? any HasAttributes,
        let word = attributedBlock.layer as? Text
      {
        let scale = attributedBlock.attributes.scale ?? defaultScale
        let foreground = attributedBlock.attributes.foreground ?? .white
        let background = attributedBlock.attributes.background ?? .black
        drawer.drawText(word.draw(at: (pos.y, pos.x), scale: scale, forground: foreground, background: background))
      } else if let word = block as? Text {
        drawer.drawText(word.draw(at: (pos.y, pos.x)))
      } else if let attributedBlock = block as? any HasAttributes,
        attributedBlock.layer as? Rectangle != nil,
        let size = sizes[currentId]
      {
        let quad = Quad(
          dst_p0: (pos.x, pos.y),
          dst_p1: (pos.x + size.width, pos.y + size.height),
          tex_tl: (0, 0),
          tex_br: (1, 1),
          color: attributedBlock.attributes.background ?? .white,
          borderColor: attributedBlock.attributes.borderColor ?? .black,
          borderWidth: Float(attributedBlock.attributes.borderWidth ?? 0),
          cornerRadius: Float(attributedBlock.attributes.borderRadius ?? 0)
        )
        drawer.drawQuad(quad)
      } else if let size = sizes[currentId],
        block is Rectangle
      {
        let quad = Quad(
          dst_p0: (pos.x, pos.y),
          dst_p1: (pos.x + size.width, pos.y + size.height),
          tex_tl: (0, 0),
          tex_br: (1, 1),
          color: .white,
          borderColor: .black,
          borderWidth: 0.0,
          cornerRadius: 0.0
        )
        drawer.drawQuad(quad)
      } else {
        logger.warning("Unable to render :\(currentId) \(type(of: block))")
      }
    } else {
      logger.warning("No position for \(currentId)")
    }
  }

  mutating func after(_ block: some Block) {}
  mutating func before(child block: some Block) {}
  mutating func after(child block: some Block) {}
}
