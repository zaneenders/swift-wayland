import Testing

@testable import SwiftWayland
@testable import Wayland

enum TestRenderer: Renderer {
  static func drawQuad(_ quad: Quad) {}
  static func drawText(_ text: Text) {}
}

@MainActor
@Test
func layout() {
  var sizer = SizeWalker()
  let test = LayoutTest()
  test.walk(with: &sizer)
  let root = sizer.tree[0]![0]
  #expect(sizer.sizes[root]! == .known(height: 84, width: 348, .vertical))
  var positioner = PositionWalker(sizes: sizer.sizes)
  test.walk(with: &positioner)
  var renderWalker = RenderWalker(positions: positioner.positions, TestRenderer.self)
  test.walk(with: &renderWalker)
}
