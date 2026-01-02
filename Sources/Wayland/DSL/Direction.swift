/// Specifiies the direction in which to layout the child elements.
public struct Direction<B: Block>: Block, DirectionGroup {
  let orientation: Orientation
  let wrapped: B

  public init(_ orientation: Orientation, @BlockParser group: () -> B) {
    self.orientation = orientation
    self.wrapped = group()
  }

  public var layer: some Block {
    wrapped
  }
}

public enum Orientation {
  case horizontal
  case vertical
}

@MainActor
protocol DirectionGroup {
  var orientation: Orientation { get }
}
