public struct Solid: Block {
    public init() {}
    var quad: Quad {
        Quad(
            dst_p0: (0, 0),
            dst_p1: (20, 20),
            tex_tl: (0, 0),
            tex_br: (1, 1),
            color: .white
        )
    }
}
