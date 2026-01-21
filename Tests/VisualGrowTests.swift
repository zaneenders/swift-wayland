import Fixtures
import Testing

@testable import ShapeTree
@testable import SwiftWayland
@testable import Wayland

@MainActor
struct VisualGrowTests {

  @Test
  func growDemoFunctionalityTest() {
    let block = FullGrowDemo()

    var attributesWalker = AttributesWalker()
    block.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    block.walk(with: &sizer)

    let rootId = attributesWalker.tree[0]![0]
    sizer.sizes[rootId] = .known(Container(height: 400, width: 600, orientation: .vertical))

    let containers = sizer.sizes.convert()
    var grower = GrowWalker(sizes: containers, attributes: attributesWalker.attributes, tree: attributesWalker.tree)
    block.walk(with: &grower)

    let growElement = attributesWalker.tree[rootId]![0]
    if let grownSize = grower.sizes[growElement] {
      #expect(grownSize.width == 600)
      #expect(grownSize.height == 400)
    } else {
      Issue.record("Failed to parse tree")
    }
  }
}
