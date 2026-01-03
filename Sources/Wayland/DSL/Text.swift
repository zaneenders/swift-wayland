public struct Text: Block {
  let label: String

  public init(_ text: String) {
    self.label = text
  }

  func width(_ scale: UInt = 1) -> UInt {
    // (size of the charaters) * (number of space) - (trailing space)
    return (UInt(label.count) * Wayland.glyphW * scale) + (UInt(label.count) * scale) - scale
  }

  func height(_ scale: UInt = 1) -> UInt {
    Wayland.glyphH * scale
  }

  func draw(at: (y: UInt, x: UInt), scale: UInt = 1, forground: Color = .white, background: Color = .black)
    -> RenderableText
  {
    return RenderableText(
      label, at: (x: at.x, y: at.y),
      scale: scale,
      forground: forground,
      background: background)
  }
}

enum VLayout {
  case center
}
enum HLayout {
  case center
}
