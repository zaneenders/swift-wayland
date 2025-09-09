internal struct Quad: BitwiseCopyable {
    var dst_p0: (Float, Float)
    var dst_p1: (Float, Float)
    var tex_tl: (Float, Float)
    var tex_br: (Float, Float)
    var color: Color
}
