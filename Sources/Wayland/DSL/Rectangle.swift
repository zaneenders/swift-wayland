public typealias Rect = Recttangle
/// A zero widht and height recttangle for which modifiers can be applied to make other shapes.
public struct Recttangle: Block {
  public var layer: some Block {}
  public init() {}
}

extension Block {
  public func width(_ width: UInt) -> some Block { self }
  public func height(_ width: UInt) -> some Block { self }
  public func forground(_ color: Color) -> some Block { self }
  public func background(_ color: Color) -> some Block { self }
  public func border(color: Color) -> some Block { self }
  public func border(width: UInt) -> some Block { self }
  public func border(radius: UInt) -> some Block { self }
  public func scale(_ scale: UInt) -> some Block { self }
}
