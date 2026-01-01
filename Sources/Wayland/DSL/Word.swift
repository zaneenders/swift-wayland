public struct Word: Block {
  let label: String
  var v: VLayout = .center
  var h: HLayout = .center
  var scale: UInt = UInt(Wayland.scale)
  var forground: Color = .white
  var background: Color = .black

  public init(_ text: String) {
    self.label = text
  }

  public func scale(_ scale: UInt = 2) -> Self {
    var copy = self
    copy.scale = scale
    return copy
  }

  public func background(_ color: Color) -> Self {
    var copy = self
    copy.background = color
    return copy
  }

  public func forground(_ color: Color) -> Self {
    var copy = self
    copy.forground = color
    return copy
  }

  var width: UInt {
    // (size of the charaters) * (number of space) - (trailing space)
    (UInt(label.count) * Wayland.glyphW * self.scale) + (UInt(label.count) * self.scale) - self.scale
  }

  var height: UInt {
    Wayland.glyphH * self.scale
  }

  func draw(at: (y: UInt, x: UInt)) -> Text {
    return Text(
      label, at: (x: at.x, y: at.y),
      scale: self.scale,
      forground: self.forground,
      background: self.background)
  }
}

enum VLayout {
  case center
}
enum HLayout {
  case center
}
