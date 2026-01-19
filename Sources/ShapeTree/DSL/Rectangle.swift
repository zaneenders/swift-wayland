public typealias Rect = Rectangle
/// A zero widht and height recttangle for which modifiers can be applied to make other shapes.
public struct Rectangle: Block {
  public var layer: some Block {}
  public init() {}
}
