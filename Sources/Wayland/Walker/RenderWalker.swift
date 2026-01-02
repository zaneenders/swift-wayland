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
      } else if let rect = block as? RenderableRect {
        drawer.drawQuad(Quad(pos: pos, rect))
      }
    } else {
      logger.warning("No position for \(currentId)")
    }
  }

  mutating func after(_ block: some Block) {}
  mutating func before(child block: some Block) {}
  mutating func after(child block: some Block) {}
}
