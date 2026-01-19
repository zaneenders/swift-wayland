import ShapeTree

struct RenderableText {
  public let text: String
  public let pos: (x: UInt, y: UInt)
  public let scale: UInt
  public var foreground: Color
  public var background: Color

  init(
    _ text: String,
    at pos: (x: UInt, y: UInt),
    scale: UInt,
    foreground: Color = .white,
    background: Color = .black
  ) {
    self.text = text
    self.pos = pos
    self.scale = scale
    self.foreground = foreground
    self.background = background
  }
}
