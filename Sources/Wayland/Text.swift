public struct Text {
  public let text: String
  public let pos: (x: UInt, y: UInt)
  public let scale: UInt
  public var forground: Color
  public var background: Color

  public init(
    _ text: String,
    at pos: (x: UInt, y: UInt),
    scale: UInt,
    forground: Color = .white,
    background: Color = .black
  ) {
    self.text = text
    self.pos = pos
    self.scale = scale
    self.forground = forground
    self.background = background
  }
}
