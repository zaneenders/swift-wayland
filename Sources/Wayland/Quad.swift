internal struct Quad: BitwiseCopyable {
    var dst_p0: (Float, Float)
    var dst_p1: (Float, Float)
    var tex_tl: (Float, Float)
    var tex_br: (Float, Float)
    var color: Color

    var height: Float {
        abs(dst_p0.0 - dst_p1.0)
    }
    var width: Float {
        abs(dst_p0.1 - dst_p1.1)
    }

    init(
        dst_p0: (Float, Float), dst_p1: (Float, Float),
        tex_tl: (Float, Float) = (0, 0),
        tex_br: (Float, Float) = (1, 1),
        color: Color
    ) {
        self.dst_p0 = dst_p0
        self.dst_p1 = dst_p1
        self.tex_tl = tex_tl
        self.tex_br = tex_br
        self.color = color
    }
}
