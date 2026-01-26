public struct Attributes {
  public var width: Sizing
  public var height: Sizing
  public var foreground: Color?
  public var background: Color?
  public var borderColor: Color?
  public var borderWidth: UInt?
  public var borderRadius: UInt?
  public var scale: UInt?
  public var padding: Padding?

  public init(
    width: Sizing = .fit, height: Sizing = .fit,
    foreground: Color? = nil, background: Color? = nil,
    borderColor: Color? = nil, borderWidth: UInt? = nil,
    borderRadius: UInt? = nil, scale: UInt? = nil,
    padding: Padding? = nil
  ) {
    self.width = width
    self.height = height
    self.foreground = foreground
    self.background = background
    self.borderColor = borderColor
    self.borderWidth = borderWidth
    self.borderRadius = borderRadius
    self.scale = scale
    self.padding = padding
  }

  public func merge(_ other: Attributes) -> Attributes {
    var copy = self
    if other.width != .fit {
      copy.width = other.width
    }
    if other.height != .fit {
      copy.height = other.height
    }
    if other.foreground != nil {
      copy.foreground = other.foreground
    }
    if other.background != nil {
      copy.background = other.background
    }
    if other.borderColor != nil {
      copy.borderColor = other.borderColor
    }
    if other.borderWidth != nil {
      copy.borderWidth = other.borderWidth
    }
    if other.borderRadius != nil {
      copy.borderRadius = other.borderRadius
    }
    if other.scale != nil {
      copy.scale = other.scale
    }
    if other.padding != nil {
      copy.padding = other.padding
    }
    return copy
  }
}
