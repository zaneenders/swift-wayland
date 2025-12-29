@MainActor
public protocol Renderer {
  static func drawText(_ text: Text)
  static func drawQuad(_ quad: Quad)
}

public struct RenderWalker: Walker {
  public var currentId: Hash = 0
  public var parentId: Hash = 0
  private var positions: [Hash: (x: UInt, y: UInt)] = [:]
  private let drawer: Renderer.Type

  public init(
    positions: [Hash: (x: UInt, y: UInt)],
    _ drawer: any Renderer.Type
  ) {
    self.positions = positions
    self.drawer = drawer
  }

  public mutating func before(_ block: some Block) {
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

  public mutating func after(_ block: some Block) {}
  public mutating func before(child block: some Block) {}
  public mutating func after(child block: some Block) {}
}
