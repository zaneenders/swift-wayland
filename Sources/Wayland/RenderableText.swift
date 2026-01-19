import ShapeTree

struct RenderableText {
  public let text: String
  public let pos: (x: UInt, y: UInt)
  public let scale: UInt
  public var foreground: RGB
  public var background: RGB

  init(
    _ text: String,
    at pos: (x: UInt, y: UInt),
    scale: UInt,
    foreground: RGB = Color.white.rgb(),
    background: RGB = Color.black.rgb()
  ) {
    self.text = text
    self.pos = pos
    self.scale = scale
    self.foreground = foreground
    self.background = background
  }
}
