public enum WaylandEvent: Sendable {
    #if !Toolbar
    case key(code: UInt, state: UInt)
    #endif
    case frame(height: UInt, width: UInt)
}
