import Testing

@testable import SwiftWayland
@testable import Wayland

@MainActor
@Test
func layout() {
  var sizer = SizeWalker()
  let test = LayoutTest()
  test.walk(with: &sizer)
}

struct LayoutTest: Block {
  let scale: UInt = 8
  var layer: some Block {
    Group(.horizontal) {
      Word("Left").scale(scale)
      Group(.vertical) {
        Word("Top").scale(scale)
        Group(.horizontal) {
          for a in 0..<5 {
            if a.isMultiple(of: 2) {
              Word("\(a)").scale(scale)
            }
          }
        }
        Word("Bottom").scale(scale)
      }
      Word("Right").scale(scale)
    }
  }
}

struct SizeWalker: Walker {
  var currentId: Hash = 0
  var sizes: [Hash: (height: Int, width: Int)] = [:]

  mutating func before(_ block: some Block) {
    if let rect = block as? Rect {

    } else if let text = block as? Word {
      guard text.label.contains("\n") else {
        fatalError("New lines not supported yet")
      }
      let charCount = text.label.count
    }
    print(#function)
  }

  mutating func after(_ block: some Block) {
    print(#function)
  }

  mutating func before(child block: some Block) {
    print(#function)
  }

  mutating func after(child block: some Block) {
    print(#function)
  }
}
