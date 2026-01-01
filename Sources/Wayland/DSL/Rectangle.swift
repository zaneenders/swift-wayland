public typealias Rect = Rectangle

public struct Rectangle: Block {
  let color: Color
  let height: UInt
  let width: UInt
  var scale: UInt = UInt(Wayland.scale)
  let borderWidth: UInt
  let borderColor: Color

  public init(
    width: UInt, height: UInt, color: Color, scale: UInt, borderWidth: UInt = 0,
    borderColor: Color = Color(r: 0, g: 0, b: 0, a: 0)
  ) {
    self.width = width
    self.height = height
    self.color = color
    self.scale = scale
    self.borderWidth = borderWidth
    self.borderColor = borderColor
  }
}
