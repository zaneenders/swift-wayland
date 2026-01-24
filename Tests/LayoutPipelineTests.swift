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

    let targetRoot = layout.sizes.first { (hash, container) in
      guard container.orientation == .vertical else { return false }
      guard let children = layout.tree[hash] else { return false }
      return children.count == 3
    }!

    let rootHash = targetRoot.key
    let children = layout.tree[rootHash]!
    #expect(children.count == 3)

    let childContainers = children.map { layout.sizes[$0]! }

    let firstSpacer = childContainers[0]
    let textContainer = childContainers[1]
    let secondSpacer = childContainers[2]

    #expect(firstSpacer.width == 0)
    #expect(firstSpacer.height > 0 && firstSpacer.height < 20)
    #expect(textContainer.width == 34 && textContainer.height == 14)
    #expect(secondSpacer.width == 0)
    #expect(secondSpacer.height > 0 && secondSpacer.height < 20)

    let firstSpacerPos = layout.positions[children[0]]!
    let textPos = layout.positions[children[1]]!
    let secondSpacerPos = layout.positions[children[2]]!

    #expect(firstSpacerPos.y == 0)
    #expect(textPos.y == firstSpacer.height)
    #expect(secondSpacerPos.y == firstSpacer.height + textContainer.height)
  }
}
