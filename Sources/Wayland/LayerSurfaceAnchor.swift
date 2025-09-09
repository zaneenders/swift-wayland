#if Toolbar
struct LayerSurfaceAnchor: OptionSet {
    let rawValue: UInt32

    static let top = LayerSurfaceAnchor(rawValue: 1 << 0)
    static let bottom = LayerSurfaceAnchor(rawValue: 1 << 1)
    static let left = LayerSurfaceAnchor(rawValue: 1 << 2)
    static let right = LayerSurfaceAnchor(rawValue: 1 << 3)
}
#endif
