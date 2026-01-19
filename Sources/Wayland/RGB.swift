import ShapeTree

public struct RGB: BitwiseCopyable, Sendable, Equatable {

  public var r, g, b, a: Float

  public init(r: Float, g: Float, b: Float, a: Float) {
    self.r = r
    self.g = g
    self.b = b
    self.a = a
  }
}

extension Color {
  func rgb() -> RGB {
    switch self {
    case .black:
      RGB(r: 0, g: 0, b: 0, a: 1)
    case .blue:
      RGB(r: 0.0, g: 0.0, b: 1.0, a: 1.0)
    case .brown:
      RGB(r: 0.4, g: 0.25, b: 0.1, a: 1.0)
    case .cyan:
      RGB(r: 0.0, g: 1.0, b: 1.0, a: 1.0)
    case .gray:
      RGB(r: 0.5, g: 0.5, b: 0.5, a: 1.0)
    case .green:
      RGB(r: 0.5, g: 1, b: 0.5, a: 1)
    case .magenta:
      RGB(r: 1.0, g: 0.0, b: 1.0, a: 1.0)
    case .orange:
      RGB(r: 1, g: 0.5, b: 0, a: 1)
    case .pink:
      RGB(r: 0.9, g: 0.5, b: 0.6, a: 1.0)
    case .purple:
      RGB(r: 0.5, g: 0.0, b: 0.5, a: 1.0)
    case .red:
      RGB(r: 1, g: 0, b: 0, a: 1)
    case .teal:
      RGB(r: 0, g: 1, b: 1, a: 1)
    case .white:
      RGB(r: 1, g: 1, b: 1, a: 1)
    case .yellow:
      RGB(r: 1.0, g: 1.0, b: 0.0, a: 1.0)
    }
  }
}
