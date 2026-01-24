import Testing

@testable import Fixtures
@testable import ShapeTree
@testable import Wayland

@MainActor
struct LayoutPipelineTests {

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

  @Test func verticalGrowTest() {
    // Text is height 14 so vertical spaced should center it with ~3 above and ~3 below
    // Total height: 20, Text: 14, Remaining: 6 pixels distributed between two spacers
    let block = VerticalSpacedText()
    let layout = Wayland.calculateLayout(block, height: 20, width: 600, settings: Wayland.fontSettings)

    let containers = layout.sizes.map { $0.value }
    #expect(containers.count == 10)

    let spacerContainers = containers.filter { $0.width == 0 && $0.height < 20 && $0.height > 0 }
    let textContainers = containers.filter { $0.width == 34 && $0.height == 14 }

    #expect(spacerContainers.count == 2)
    #expect(textContainers.count == 1)

    let totalSpacerHeight = spacerContainers.reduce(0) { $0 + $1.height }
    let expectedSpacerHeight = 20 - textContainers[0].height
    #expect(abs(Int(totalSpacerHeight) - Int(expectedSpacerHeight)) == 1)
  }
}
