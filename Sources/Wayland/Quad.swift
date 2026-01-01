struct Quad: BitwiseCopyable {
  var dst_p0: (Float, Float)
  var dst_p1: (Float, Float)
  var tex_tl: (Float, Float)
  var tex_br: (Float, Float)
  var color: Color
  var borderColor: Color
  var borderWidth: Float

  var height: UInt {
    UInt(abs(dst_p0.1 - dst_p1.1))
  }
  var width: UInt {
    UInt(abs(dst_p0.0 - dst_p1.0))
  }

  init(pos: (x: UInt, y: UInt), _ rect: Rect) {
    let scaledWidth = rect.width * rect.scale
    let scaledHeight = rect.height * rect.scale
    self.dst_p0 = (Float(pos.x), Float(pos.y))
    self.dst_p1 = (Float(pos.x + scaledWidth), Float(pos.y + scaledHeight))
    self.tex_tl = (0, 0)
    self.tex_br = (1, 1)
    self.color = rect.color
    self.borderColor = rect.borderColor ?? Color(r: 0, g: 0, b: 0, a: 0)
    self.borderWidth = Float(rect.borderWidth)
  }

  init(
    dst_p0: (UInt, UInt), dst_p1: (UInt, UInt),
    tex_tl: (Float, Float) = (0, 0),
    tex_br: (Float, Float) = (1, 1),
    color: Color,
    borderColor: Color = Color(r: 0, g: 0, b: 0, a: 0),
    borderWidth: Float = 0.0
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
    self.borderColor = borderColor
    self.borderWidth = borderWidth
  }
}
