struct Rect {
    var dst_p0: (Float, Float)
    var dst_p1: (Float, Float)
    var color: Color

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
