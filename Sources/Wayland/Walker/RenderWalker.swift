import Logging

struct RenderWalker: Walker {
  var currentId: Hash = 0
  var parentId: Hash = 0
  let logger: Logger
  private var positions: [Hash: (x: UInt, y: UInt)] = [:]
  private let drawer: Renderer.Type

  init(
    positions: [Hash: (x: UInt, y: UInt)],
    _ drawer: any Renderer.Type,
    logLevel: Logger.Level
  ) {
    self.positions = positions
    self.drawer = drawer
    self.logger = Logger.create(logLevel: logLevel)
  }

  mutating func before(_ block: some Block) {
    if let pos = positions[currentId] {
      if let word = block as? Text {
        drawer.drawText(word.draw(at: (pos.y, pos.x)))
      } else if block is Recttangle {
        let quad = Quad(
          dst_p0: (pos.x, pos.y),
          dst_p1: (pos.x + 100, pos.y + 50),
          tex_tl: (0, 0),
          tex_br: (1, 1),
          color: .white,
          borderColor: .black,
          borderWidth: 0.0,
          cornerRadius: 0.0
        )
        drawer.drawQuad(quad)
      }
    } else {
      logger.warning("No position for \(currentId)")
    }
  }

  mutating func after(_ block: some Block) {}
  mutating func before(child block: some Block) {}
  mutating func after(child block: some Block) {}
}
