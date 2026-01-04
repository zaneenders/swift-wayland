struct Attributes {
  var width: UInt?
  var height: UInt?
  var foreground: Color?
  var background: Color?
  var borderColor: Color?
  var borderWidth: UInt?
  var borderRadius: UInt?
  var scale: UInt?

  init() {}

  init(
    width: UInt? = nil, height: UInt? = nil, foreground: Color? = nil, background: Color? = nil,
    borderColor: Color? = nil, borderWidth: UInt? = nil, borderRadius: UInt? = nil, scale: UInt? = nil
  ) {
    self.width = width
    self.height = height
    self.foreground = foreground
    self.background = background
    self.borderColor = borderColor
    self.borderWidth = borderWidth
    self.borderRadius = borderRadius
    self.scale = scale
  }

  func apply(_ other: Attributes) -> Attributes {
    var copy = self
    copy.width = other.width
    copy.height = other.height
    copy.foreground = other.foreground
    copy.background = other.background
    copy.borderColor = other.borderColor
    copy.borderWidth = other.borderWidth
    copy.borderRadius = other.borderRadius
    copy.scale = other.scale
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
  public func width(_ width: UInt) -> AttributedBlock<Self> {
    var newBlock = AttributedBlock(wrapped: self)
    newBlock.attributes.width = width
    return newBlock
  }

  public func height(_ height: UInt) -> AttributedBlock<Self> {
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
  public func width(_ width: UInt) -> Self {
    var copy = self
    copy.attributes.width = width
    return copy
  }

  public func height(_ height: UInt) -> Self {
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
