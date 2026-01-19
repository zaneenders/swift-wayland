import ShapeTree

public struct LeftPadding: Block {
  public init() {}
  public var layer: some Block {
    Direction(.horizontal) {
      Rect().width(.grow)
      Text("Right")
    }
  }
}
