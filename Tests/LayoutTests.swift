import Testing

@testable import SwiftWayland
@testable import Wayland

@MainActor
@Test
func layout() {
  var sizer = SizeWalker()
  let test = LayoutTest()
  test.walk(with: &sizer)
  print(sizer.sizes)
}

struct SizeWalker: Walker {
  var currentId: Hash = 0
  var sizes: [Hash: (height: UInt, width: UInt)] = [:]

  mutating func before(_ block: some Block) {
    if let rect = block as? Rect {

    } else if let text = block as? Word {
      guard !text.label.contains("\n") else {
        fatalError("New lines not supported yet")
      }
      print(currentId, text.label)
      let width = UInt(text.label.count) * text.scale
      let height = 1 * text.scale
      sizes[currentId] = (height, width)
    }
  }

  mutating func after(_ block: some Block) {}

  mutating func before(child block: some Block) {}

  mutating func after(child block: some Block) {}
}
