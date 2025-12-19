import Logging
import Testing

@testable import SwiftWayland
@testable import Wayland

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

@MainActor
@Suite(.serialized)
struct BlockTests: ~Copyable {

  var renderer: LayoutMachine
  init() {
    self.renderer = LayoutMachine(TestWayland.self, .error)
    TestWayland.reset()
  }

  @Test
  mutating func test1() {
    let tb = Test1(o: .horizontal)
    tb.draw(&renderer)
    #expect(TestWayland.texts.count == 2)
    #expect(TestWayland.quads.count == 0)
  }

  @Test
  mutating func screen() {
    let screen = Screen(o: .vertical, ips: ["Zane"])
    screen.draw(&renderer)
    #expect(TestWayland.texts.count == 2)
    #expect(TestWayland.quads.count == 1)
  }
}
