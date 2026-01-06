import Logging

@MainActor
struct GrowWalker: Walker {
  var currentId: Hash = 0
  var parentId: Hash = 0
  let sizes: [Hash: Container]
  let attributes: [Hash: Attributes]

  mutating func action() {
    let container = sizes[currentId]!
    if let attributes = attributes[currentId] {
      if case .grow = attributes.height {
      }
      if case .grow = attributes.width {
      }
    }
  }

  mutating func before(_ block: some Block) {
    action()
  }

  mutating func after(_ block: some Block) {
    action()
  }

  mutating func before(child block: some Block) {}
  mutating func after(child block: some Block) {}
}
