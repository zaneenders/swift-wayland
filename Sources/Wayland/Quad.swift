public struct Quad: BitwiseCopyable {
  var dst_p0: (Float, Float)
  var dst_p1: (Float, Float)
  var tex_tl: (Float, Float)
  var tex_br: (Float, Float)
  var color: Color

  var height: UInt {
    UInt(abs(dst_p0.0 - dst_p1.0))
  }
  var width: UInt {
    UInt(abs(dst_p0.1 - dst_p1.1))
  }

  public init(pos: (x: UInt, y: UInt), _ rect: Rect) {
    let quad = Quad(
      dst_p0: (pos.x, pos.y),
      dst_p1: (pos.x + rect.width, pos.y + rect.height),
      tex_tl: (0, 0), tex_br: (1, 1), color: rect.color)
    self = quad
  }

  public init(
    dst_p0: (UInt, UInt), dst_p1: (UInt, UInt),
    tex_tl: (Float, Float) = (0, 0),
    tex_br: (Float, Float) = (1, 1),
    color: Color
  ) {
    // NOTE: Converting to Float right here looks to be about a 2x slow down.
    // Long term I think it will be better to do this allocation farther up
    // the stack frame but for now I want to stick to integer math as we are
    // only using monospace font
    self.dst_p0 = (Float(dst_p0.0), Float(dst_p0.1))
    self.dst_p1 = (Float(dst_p1.0), Float(dst_p1.1))
    self.tex_tl = tex_tl
    self.tex_br = tex_br
    self.color = color
  }
}
