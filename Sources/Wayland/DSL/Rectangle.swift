public typealias Rect = Rectangle

public struct Rectangle: Block {
  let color: Color
  let height: UInt
  let width: UInt
  var scale: UInt = UInt(Wayland.scale)

  public init(width: UInt, height: UInt, color: Color, scale: UInt) {
    self.width = width
    self.height = height
    self.color = color
    self.scale = scale
  }
}
