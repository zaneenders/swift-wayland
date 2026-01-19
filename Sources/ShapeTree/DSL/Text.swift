public struct Text: Block {
  public let label: String

  public init(_ text: String) {
    self.label = text
  }

  public func width(_ scale: UInt, using fontMetrics: some FontMetrics) -> UInt {
    // (size of the characters) * (number of spaces) - (trailing space)
    return (UInt(label.count) * fontMetrics.glyphWidth * scale) + (UInt(label.count) * fontMetrics.glyphSpacing * scale)
      - (fontMetrics.glyphSpacing * scale)
  }

  public func height(_ scale: UInt = 1, using fontMetrics: some FontMetrics) -> UInt {
    fontMetrics.glyphHeight * scale
  }
}
