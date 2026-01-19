import Testing
import Wayland

@testable import ShapeTree

@MainActor
struct LayoutPipelineTests {

  @Test
  func testCalculateLayout() {
    let block = Text("Hello")
    let height: UInt = 100
    let width: UInt = 200

    let layout = Wayland.calculateLayout(block, height: height, width: width)

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
    #expect(size.width <= width)
    #expect(size.height <= height)
  }

  @Test
  func testBackwardCompatibility() {
    let block = Text("Hello")
    let height: UInt = 100
    let width: UInt = 200

    let layout = Wayland.calculateLayout(block, height: height, width: width)

    #expect(layout.positions.count > 0)
    #expect(layout.sizes.count > 0)
  }

  @Test
  func testLayoutPipelineSeparation() {
    let block = Text("Pipeline Test")

    let layout = Wayland.calculateLayout(block, height: 50, width: 300)

    #expect(layout.positions.count == layout.sizes.count)
    #expect(layout.tree.count > 0)

    for id in layout.positions.keys {
      #expect(layout.sizes[id] != nil)
    }
  }
}
