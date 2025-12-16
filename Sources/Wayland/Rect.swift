public struct Rect {

  public let dst_p0: (UInt, UInt)
  public let dst_p1: (UInt, UInt)
  public let color: Color

  public init(dst_p0: (UInt, UInt), dst_p1: (UInt, UInt), color: Color) {
    self.dst_p0 = dst_p0
    self.dst_p1 = dst_p1
    self.color = color
  }

  var quad: Quad {
    Quad(
      dst_p0: dst_p0,
      dst_p1: dst_p1,
      tex_tl: (0, 0),
      tex_br: (1, 1),
      color: color
    )
  }
}
