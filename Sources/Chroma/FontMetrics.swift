public struct FontMetrics: Equatable, Sendable {
  public var glyphWidth: Float = 20
  public var glyphHeight: Float = 28
  // Noto Sans Mono: 36 pixels of advance at 3x atlas resolution.
  public var readableAdvance: Float = 12
  public var glyphSpacing: Float = 0
  public var lineAdvance: Float = 32

  public init() {}

  public var cellAdvance: Float { readableAdvance }
  public var displayCellAdvance: Float { cellAdvance }

  public func advance(for face: FontFace) -> Float {
    cellAdvance
  }

  public func measure(_ text: String, scale: Float = 1, face: FontFace = .readable) -> Size {
    Size(width: Float(text.count) * advance(for: face) * scale, height: glyphHeight * scale)
  }
}
