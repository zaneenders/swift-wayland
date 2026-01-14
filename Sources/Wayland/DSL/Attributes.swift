struct Padding: Equatable {
  var top: UInt?
  var right: UInt?
  var bottom: UInt?
  var left: UInt?

  init() {}

  init(all: UInt) {
    self.top = all
    self.right = all
    self.bottom = all
    self.left = all
  }

  init(top: UInt? = nil, right: UInt? = nil, bottom: UInt? = nil, left: UInt? = nil) {
    self.top = top
    self.right = right
    self.bottom = bottom
    self.left = left
  }

  init(horizontal: UInt, vertical: UInt) {
    self.top = vertical
    self.bottom = vertical
    self.left = horizontal
    self.right = horizontal
  }
}

public enum Sizing: Equatable {
  case fixed(UInt)  // Specify a specify size
  case fit  // Fit to the size needed
  case grow  // Grow to the space allowed
}

struct Attributes {
  var width: Sizing
  var height: Sizing
  var foreground: Color?
  var background: Color?
  var borderColor: Color?
  var borderWidth: UInt?
  var borderRadius: UInt?
  var scale: UInt?
  var padding: Padding?

  init(
    width: Sizing = .fit, height: Sizing = .fit, foreground: Color? = nil, background: Color? = nil,
    borderColor: Color? = nil, borderWidth: UInt? = nil, borderRadius: UInt? = nil, scale: UInt? = nil,
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

  func merge(_ other: Attributes) -> Attributes {
    var copy = self
    // NOTE: should width and height override here?
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

protocol HasAttributes: Block {
  var attributes: Attributes { get set }
}

public struct AttributedBlock<B: Block>: Block, HasAttributes {
  var attributes = Attributes()

  var wrapped: B
  public var layer: B {
    wrapped
  }
}

extension Block {
  public func width(_ width: Sizing) -> AttributedBlock<Self> {
    var newBlock = AttributedBlock(wrapped: self)
    newBlock.attributes.width = width
    return newBlock
  }

  public func height(_ height: Sizing) -> AttributedBlock<Self> {
    var newBlock = AttributedBlock(wrapped: self)
    newBlock.attributes.height = height
    return newBlock
  }

  public func background(_ color: Color) -> AttributedBlock<Self> {
    var newBlock = AttributedBlock(wrapped: self)
    newBlock.attributes.background = color
    return newBlock
  }

  public func border(color: Color) -> AttributedBlock<Self> {
    var newBlock = AttributedBlock(wrapped: self)
    newBlock.attributes.borderColor = color
    return newBlock
  }

  public func border(width: UInt) -> AttributedBlock<Self> {
    var newBlock = AttributedBlock(wrapped: self)
    newBlock.attributes.borderWidth = width
    return newBlock
  }

  public func border(radius: UInt) -> AttributedBlock<Self> {
    var newBlock = AttributedBlock(wrapped: self)
    newBlock.attributes.borderRadius = radius
    return newBlock
  }

  public func padding(_ padding: UInt) -> AttributedBlock<Self> {
    var newBlock = AttributedBlock(wrapped: self)
    newBlock.attributes.padding = Padding(all: padding)
    return newBlock
  }

  public func padding(top: UInt, right: UInt, bottom: UInt, left: UInt) -> AttributedBlock<Self> {
    var newBlock = AttributedBlock(wrapped: self)
    newBlock.attributes.padding = Padding(top: top, right: right, bottom: bottom, left: left)
    return newBlock
  }

  public func padding(horizontal: UInt, vertical: UInt) -> AttributedBlock<Self> {
    var newBlock = AttributedBlock(wrapped: self)
    newBlock.attributes.padding = Padding(horizontal: horizontal, vertical: vertical)
    return newBlock
  }

  public func padding(top: UInt, right: UInt? = nil, bottom: UInt? = nil, left: UInt? = nil) -> AttributedBlock<
    Self
  > {
    var newBlock = AttributedBlock(wrapped: self)
    newBlock.attributes.padding = Padding(top: top, right: right, bottom: bottom, left: left)
    return newBlock
  }

  public func padding(top: UInt? = nil, right: UInt, bottom: UInt? = nil, left: UInt? = nil) -> AttributedBlock<
    Self
  > {
    var newBlock = AttributedBlock(wrapped: self)
    newBlock.attributes.padding = Padding(top: top, right: right, bottom: bottom, left: left)
    return newBlock
  }

  public func padding(top: UInt? = nil, right: UInt? = nil, bottom: UInt, left: UInt? = nil) -> AttributedBlock<
    Self
  > {
    var newBlock = AttributedBlock(wrapped: self)
    newBlock.attributes.padding = Padding(top: top, right: right, bottom: bottom, left: left)
    return newBlock
  }

  public func padding(top: UInt? = nil, right: UInt? = nil, bottom: UInt? = nil, left: UInt) -> AttributedBlock<
    Self
  > {
    var newBlock = AttributedBlock(wrapped: self)
    newBlock.attributes.padding = Padding(top: top, right: right, bottom: bottom, left: left)
    return newBlock
  }
}

extension Text {
  public func foreground(_ color: Color) -> AttributedBlock<Self> {
    var newBlock = AttributedBlock(wrapped: self)
    newBlock.attributes.foreground = color
    return newBlock
  }
  public func scale(_ scale: UInt) -> AttributedBlock<Self> {
    var newBlock = AttributedBlock(wrapped: self)
    newBlock.attributes.scale = scale
    return newBlock
  }
}

// Support for chaining on AttributedBlock
extension AttributedBlock {

  public func width(_ width: Sizing) -> Self {
    var copy = self
    copy.attributes.width = width
    return copy
  }

  public func height(_ height: Sizing) -> Self {
    var copy = self
    copy.attributes.height = height
    return copy
  }

  public func background(_ color: Color) -> Self {
    var copy = self
    copy.attributes.background = color
    return copy
  }

  public func border(color: Color) -> Self {
    var copy = self
    copy.attributes.borderColor = color
    return copy
  }

  public func border(width: UInt) -> Self {
    var copy = self
    copy.attributes.borderWidth = width
    return copy
  }

  public func border(radius: UInt) -> Self {
    var copy = self
    copy.attributes.borderRadius = radius
    return copy
  }

  public func padding(_ padding: UInt) -> Self {
    var copy = self
    copy.attributes.padding = Padding(all: padding)
    return copy
  }

  public func padding(top: UInt, right: UInt, bottom: UInt, left: UInt) -> Self {
    var copy = self
    copy.attributes.padding = Padding(top: top, right: right, bottom: bottom, left: left)
    return copy
  }

  public func padding(horizontal: UInt, vertical: UInt) -> Self {
    var copy = self
    copy.attributes.padding = Padding(horizontal: horizontal, vertical: vertical)
    return copy
  }

  public func padding(top: UInt, right: UInt? = nil, bottom: UInt? = nil, left: UInt? = nil) -> Self {
    var copy = self
    copy.attributes.padding = Padding(top: top, right: right, bottom: bottom, left: left)
    return copy
  }
  public func padding(top: UInt? = nil, right: UInt, bottom: UInt? = nil, left: UInt? = nil) -> Self {
    var copy = self
    copy.attributes.padding = Padding(top: top, right: right, bottom: bottom, left: left)
    return copy
  }
  public func padding(top: UInt? = nil, right: UInt? = nil, bottom: UInt, left: UInt? = nil) -> Self {
    var copy = self
    copy.attributes.padding = Padding(top: top, right: right, bottom: bottom, left: left)
    return copy
  }
  public func padding(top: UInt? = nil, right: UInt? = nil, bottom: UInt? = nil, left: UInt) -> Self {
    var copy = self
    copy.attributes.padding = Padding(top: top, right: right, bottom: bottom, left: left)
    return copy
  }
}

extension AttributedBlock where Component == Text {

  public func foreground(_ color: Color) -> Self {
    var copy = self
    copy.attributes.foreground = color
    return copy
  }

  public func scale(_ scale: UInt) -> Self {
    var copy = self
    copy.attributes.scale = scale
    return copy
  }
}
