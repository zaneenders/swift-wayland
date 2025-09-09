public enum WaylandEvent: Sendable {
    #if !Toolbar
    case key(code: UInt32, state: UInt32)
    #endif
    case frame(height: UInt32, width: UInt32)
}
