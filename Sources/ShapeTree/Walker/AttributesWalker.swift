@MainActor
struct AttributesWalker: Walker {
  var currentId: Hash = 0
  var parentId: Hash = 0
  var tree: [Hash: [Hash]] = [:]
  var attributes: [Hash: Attributes] = [:]
  private var current: Attributes = Attributes()

  private mutating func connect(parent: Hash, current: Hash) {
    if var sibilings = tree[parent] {
      sibilings.append(current)
      tree[parent] = sibilings
    } else {
      tree[parent] = [current]
    }
  }

  mutating func before(_ block: some Block) {
    connect(parent: parentId, current: currentId)
    if let attributedBlock = block as? any HasAttributes {
      // Reset current to default for this block, then merge with block's specific attributes
      // Each block should have its own independent attributes, not inherit from siblings
      current = Attributes()
      current = current.merge(attributedBlock.attributes)
      attributes[currentId] = current
    }
  }

  mutating func after(_ block: some Block) {
    current = attributes[currentId] ?? Attributes()
  }

  mutating func before(child block: some Block) {}
  mutating func after(child block: some Block) {}
}
