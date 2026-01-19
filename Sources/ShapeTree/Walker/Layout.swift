public struct Layout {
  public let positions: [Hash: (x: UInt, y: UInt)]
  public let sizes: [Hash: Container]
  public let attributes: [Hash: Attributes]
  public let tree: [Hash: [Hash]]

  public init(
    positions: [Hash: (x: UInt, y: UInt)],
    sizes: [Hash: Container],
    attributes: [Hash: Attributes],
    tree: [Hash: [Hash]]
  ) {
    self.positions = positions
    self.sizes = sizes
    self.attributes = attributes
    self.tree = tree
  }
}
