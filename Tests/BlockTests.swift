import Logging
import Testing

@testable import SwiftWayland
@testable import Wayland

@MainActor
@Suite(.serialized)
struct BlockTests: ~Copyable {

  var renderer: LayoutMachine
  init() {
    self.renderer = LayoutMachine(TestWayland.self, .error)
    TestWayland.reset()
  }

  @Test
  mutating func horizontal() {
    // Not really testing layout placement yet.
    let tb = Test1(o: .horizontal)
    tb.walk(with: &renderer)
    #expect(TestWayland.texts.count == 2)
    #expect(TestWayland.quads.count == 0)

    #expect(TestWayland.texts[0].text == "Tyler")
    #expect(TestWayland.texts[1].text == "Mel")
    #expect(TestWayland.texts[0].scale == 4)
    #expect(TestWayland.texts[1].scale == 4)
    #expect(TestWayland.texts[0].forground == .yellow)
    #expect(TestWayland.texts[1].background == .cyan)
  }

  @Test
  mutating func screen() {
    let screen = Screen(o: .vertical, ips: ["Zane"])
    screen.walk(with: &renderer)
    #expect(TestWayland.texts.count == 2)
    #expect(TestWayland.quads.count == 1)

    #expect(TestWayland.texts[0].text == "Demo")
    #expect(TestWayland.texts[1].text == "Zane")

    #expect(TestWayland.texts[0].scale == 12)
    #expect(TestWayland.texts[0].forground == .green)
    #expect(TestWayland.texts[0].background == .cyan)
    #expect(TestWayland.texts[1].scale == 4)
    #expect(TestWayland.texts[1].forground == .white)
    #expect(TestWayland.texts[1].background == .cyan)

    #expect(TestWayland.quads.count == 1)
    #expect(TestWayland.quads[0].color == .cyan)
    #expect(TestWayland.quads[0].width == 40)  // 5 * 8 scale
    #expect(TestWayland.quads[0].height == 40)  // 5 * 8 scale
  }

  @Test func hashing() {
    var idWalker = IdWalker()
    let screen = Screen(o: .vertical, ips: ["Zane", "Was", "Here"])
    screen.walk(with: &idWalker)
    #expect(idWalker.currentId == 0)
  }

  @Test
  mutating func moveIn() {
    let screen = Screen(o: .vertical, ips: ["Zane", "Was", "Here"])
    var idWalker = IdWalker()
    screen.walk(with: &renderer)
    screen.walk(with: &idWalker)
    let p1 = renderer.selected
    print("P1", p1)
    screen.moveIn(&renderer)
    #expect(p1 != renderer.selected)
    let p2 = renderer.selected
    screen.moveIn(&renderer)
    #expect(p2 != renderer.selected)
  }
}

struct Test: Block {
  var layer: some Block {
    Group(.horizontal) {
      Word("Left")
      Group(.vertical) {
        Word("Top")
        Group(.horizontal) {
          for a in 0..<5 {
            if a.isMultiple(of: 2) {
              Word("\(a)")
            }
          }
        }
        Word("Bottom")
      }
      Word("Right")
    }
  }
}

struct IdWalker: Walker {
  var currentId: Hash = 0
  mutating func before(_ block: some Block) {
    if let word = block as? Word {
      print(currentId, word.label)
    } else {
      print(currentId)
    }
  }
  mutating func after(_ block: some Block) {}
  mutating func before(child block: some Block) {}
  mutating func after(child block: some Block) {}
}

struct StackWalker: Walker {
  var stack: [String] = []
  var currentId: Hash = 0
  mutating func before(_ block: some Block) {
    if let word = block as? Word {
      stack.append(word.label)
    } else {
      let i = "\(type(of: block))"
      stack.append(i)
    }
  }
  mutating func after(_ block: some Block) {
    let i = stack.removeLast()
    print(i)
  }
  mutating func before(child block: some Block) {}
  mutating func after(child block: some Block) {}
}

@MainActor
enum TestWayland: Renderer {
  static var texts: [Text] = []
  static var quads: [Quad] = []

  static func drawQuad(_ quad: Quad) {
    quads.append(quad)
  }

  static func drawText(_ text: Text) {
    texts.append(text)
  }

  static func reset() {
    texts = []
    quads = []
  }
}

extension Block {
  func _display(_ index: Int? = nil) {
    print(id(index))
    if self as? OrientationBlock != nil {
      self.layer._display()
    } else if self as? Rect != nil {
      // Leaf Node
    } else if self as? Word != nil {
      // Leaf Node
    } else if let group = self as? BlockGroup {
      print("Start: \(id())")
      for (index, block) in group.children.enumerated() {
        block._display(index)
      }
      print("End:   \(id())")
    } else {
      self.layer._display()
    }
  }
}
