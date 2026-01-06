import Logging

@MainActor
struct GrowWalker: Walker {
  var currentId: Hash = 0
  var parentId: Hash = 0
  let sizes: [Hash: Container]

  mutating func before(_ block: some Block) {}

  mutating func after(_ block: some Block) {}

  mutating func before(child block: some Block) {}
  mutating func after(child block: some Block) {}
}
