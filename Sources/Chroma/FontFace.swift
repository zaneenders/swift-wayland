/// Legacy wire/API values. Both render the same bundled font with the same advance.
/// Retained so existing applications and remote display lists remain compatible.
public enum FontFace: UInt8, Equatable, Sendable {
  case readable
  case display
}
