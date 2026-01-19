/// Protocol for defining font metrics used in text sizing calculations.
public protocol FontMetrics {
  var glyphWidth: UInt { get }
  var glyphHeight: UInt { get }
  var glyphSpacing: UInt { get }
}
