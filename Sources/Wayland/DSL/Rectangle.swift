public typealias Rect = Recttangle
/// A zero widht and height recttangle for which modifiers can be applied to make other shapes.
public struct Recttangle: Block {
  public var layer: some Block {}
  public init() {}
}

public struct Attributes {
  public var width: UInt?
  public var height: UInt?
  public var foreground: Color?
  public var background: Color?
  public var borderColor: Color?
  public var borderWidth: UInt?
  public var borderRadius: UInt?
  public var scale: UInt?

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
}

protocol HasAttributes: Block {
  var attributes: Attributes { get set }
}

public struct AttributedBlock<B: Block>: Block, HasAttributes {
  public var wrapped: B
  public var layer: B {
    wrapped
  }
  public var attributes = Attributes()

  public typealias Component = B
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

  public func foreground(_ color: Color) -> AttributedBlock<Self> {
    var newBlock = AttributedBlock(wrapped: self)
    newBlock.attributes.foreground = color
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

  public func foreground(_ color: Color) -> Self {
    var copy = self
    copy.attributes.foreground = color
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

  public func scale(_ scale: UInt) -> Self {
    var copy = self
    copy.attributes.scale = scale
    return copy
  }
}

