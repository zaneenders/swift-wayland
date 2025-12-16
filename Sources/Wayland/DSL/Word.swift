public struct Word: Block {
  let label: String
  var v: VLayout = .center
  var h: HLayout = .center
  var scale: UInt = UInt(Wayland.scale)
  public init(_ text: String) {
    self.label = text
  }

  public func scale(_ scale: UInt = 2) -> Self {
    var copy = self
    copy.scale = scale
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
    return Text(label, at: (at.x, at.y), scale: self.scale, color: Color.white)
  }
}

enum VLayout {
  case center
}
enum HLayout {
  case center
}
