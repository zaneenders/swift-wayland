public enum WaylandEvent: Sendable {
  case key(code: UInt, state: UInt)
  case frame(height: UInt, width: UInt)
}
