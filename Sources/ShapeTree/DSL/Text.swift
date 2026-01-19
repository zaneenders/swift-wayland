public struct Text: Block {
  public let label: String

  public init(_ text: String) {
    self.label = text
  }

  /// Calculate width using current font metrics
  public func width(_ scale: UInt = 1, using fontMetrics: FontMetrics = currentFontMetrics) -> UInt {
    // (size of the characters) * (number of spaces) - (trailing space)
    return (UInt(label.count) * fontMetrics.glyphWidth * scale) + (UInt(label.count) * fontMetrics.glyphSpacing * scale)
      - (fontMetrics.glyphSpacing * scale)
  }

  /// Calculate height using current font metrics
  public func height(_ scale: UInt = 1, using fontMetrics: FontMetrics = currentFontMetrics) -> UInt {
    fontMetrics.glyphHeight * scale
  }
}
