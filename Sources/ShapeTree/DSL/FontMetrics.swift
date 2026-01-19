/// Protocol for defining font metrics used in text sizing calculations.
public protocol FontMetrics {
  /// Width of a single glyph character
  var glyphWidth: UInt { get }

  /// Height of a single glyph character
  var glyphHeight: UInt { get }

  /// Spacing between characters
  var glyphSpacing: UInt { get }
}

/// Default font metrics implementation using a 5x7 pixel font
public struct DefaultFontMetrics: FontMetrics {
  public let glyphWidth: UInt = 5
  public let glyphHeight: UInt = 7
  public let glyphSpacing: UInt = 1

  public init() {}
}

/// Global font metrics instance used for text calculations
@MainActor
public var currentFontMetrics: FontMetrics = DefaultFontMetrics()

