import Logging

@MainActor
struct GrowWalker: Walker {
  var currentId: Hash = 0
  var parentId: Hash = 0
  var sizes: [Hash: Container]
  let attributes: [Hash: Attributes]

  mutating func before(_ block: some Block) {
    guard let parent = sizes[parentId] else {
      return
    }
    guard var container = sizes[currentId] else {
      return
    }
    if let attributes = attributes[currentId] {
      var shouldUpdate = false
      if case .grow = attributes.height {
        container.height = parent.height
        shouldUpdate = true
      }
      if case .grow = attributes.width {
        container.width = parent.width
        shouldUpdate = true
      }
      if shouldUpdate {
        sizes[currentId] = container
      }
    }
  }

  mutating func after(_ block: some Block) {}

  mutating func before(child block: some Block) {}
  mutating func after(child block: some Block) {}
}
