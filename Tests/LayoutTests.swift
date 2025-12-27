import Testing

@testable import SwiftWayland
@testable import Wayland

@MainActor
@Test
func layout() {
  var sizer = SizeWalker()
  let test = LayoutTest()
  test.walk(with: &sizer)
  for (id, element) in sizer.elements {
    print(id, element)
  }
}

enum Size {
  case unknown
  case known(height: UInt, width: UInt)
}

struct SizeWalker: Walker {
  var currentId: Hash = 0
  var elements: [Hash: Size] = [:]

  mutating func before(_ block: some Block) {
    if let rect = block as? Rect {
      let width = rect.width * rect.scale
      let height = rect.height * rect.scale
      elements[currentId] = .known(height: height, width: width)
    } else if let text = block as? Word {
      guard !text.label.contains("\n") else {
        fatalError("New lines not supported yet")
      }
      let width = UInt(text.label.count) * text.scale
      let height = 1 * text.scale
      elements[currentId] = .known(height: height, width: width)
    } else {
      elements[currentId] = .unknown
    }
  }

  mutating func after(_ block: some Block) {}
  mutating func before(child block: some Block) {}
  mutating func after(child block: some Block) {}
}
