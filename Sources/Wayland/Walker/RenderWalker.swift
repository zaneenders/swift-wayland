@MainActor
protocol Renderer {
  static func drawText(_ text: Text)
  static func drawQuad(_ quad: Quad)
}

struct RenderWalker: Walker {
  var currentId: Hash = 0
  var parentId: Hash = 0
  private var positions: [Hash: (x: UInt, y: UInt)] = [:]
  private let drawer: Renderer.Type

  init(
    positions: [Hash: (x: UInt, y: UInt)],
    _ drawer: any Renderer.Type
  ) {
    self.positions = positions
    self.drawer = drawer
  }

  mutating func before(_ block: some Block) {
    if let pos = positions[currentId] {
      if let word = block as? Word {
        drawer.drawText(Text(word.label, at: pos, scale: word.scale))
      } else if let rect = block as? Rect {
        drawer.drawQuad(Quad(pos: pos, rect))
      }
    } else {
      print("No position for \(currentId)")
    }
  }

  mutating func after(_ block: some Block) {}
  mutating func before(child block: some Block) {}
  mutating func after(child block: some Block) {}
}
