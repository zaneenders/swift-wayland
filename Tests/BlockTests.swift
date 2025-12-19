import Testing

@testable import SwiftWayland
@testable import Wayland

@MainActor
enum TestWayland: Drawer {
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

@MainActor @Test
func idk() {
  let tb = Test1(o: .horizontal)
  var renderer = Renderer(TestWayland.self)
  tb.draw(&renderer)
  print(TestWayland.texts)
  print(TestWayland.quads)
}
