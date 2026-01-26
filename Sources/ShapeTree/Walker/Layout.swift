public struct Layout {
  public let tree: [Hash: [Hash]]
  public let attributes: [Hash: Attributes]
  public let sizes: [Hash: Container]
  public let computedSizes: [Hash: Container]
  public let positions: [Hash: (x: UInt, y: UInt)]

  public init(
    tree: [Hash: [Hash]],
    attributes: [Hash: Attributes],
    sizes: [Hash: Container],
    computedSizes: [Hash: Container],
    positions: [Hash: (x: UInt, y: UInt)]
  ) {
    self.tree = tree
    self.attributes = attributes
    self.sizes = sizes
    self.computedSizes = computedSizes
    self.positions = positions
  }
}
