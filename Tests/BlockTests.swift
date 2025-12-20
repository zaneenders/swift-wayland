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
    tb.draw(&renderer)
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
    screen.draw(&renderer)
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
