import Testing

@testable import ShapeTree
@testable import Wayland

@MainActor
@Suite struct LayoutPipelineTests {

  @Test
  func testCalculateLayout() {
    let block = Text("Hello")

    let layout = Wayland.calculateLayout(
      block, height: Wayland.windowHeight, width: Wayland.windowWidth, settings: Wayland.fontSettings)

    #expect(layout.positions.count > 0)
    #expect(layout.sizes.count > 0)
    #expect(layout.tree.count > 0)

    #expect(layout.tree[0] != nil)
    let root = layout.tree[0]!.first!
    #expect(layout.positions[root] != nil)
    #expect(layout.sizes[root] != nil)

    let pos = layout.positions[root]!
    #expect(pos.x == 0)
    #expect(pos.y == 0)

    let size = layout.sizes[root]!
    #expect(size.width <= Wayland.windowWidth)
    #expect(size.height <= Wayland.windowHeight)
  }

  @Test
  func testBackwardCompatibility() {
    let block = Text("Hello")

    let layout = Wayland.calculateLayout(
      block, height: Wayland.windowHeight, width: Wayland.windowWidth, settings: Wayland.fontSettings)

    #expect(layout.positions.count > 0)
    #expect(layout.sizes.count > 0)
  }

  @Test
  func testLayoutPipelineSeparation() {
    let block = Text("Pipeline Test")

    let layout = Wayland.calculateLayout(block, height: 50, width: 300, settings: Wayland.fontSettings)

    #expect(layout.positions.count == layout.sizes.count)
    #expect(layout.tree.count > 0)

    for id in layout.positions.keys {
      #expect(layout.sizes[id] != nil)
    }
  }
}
