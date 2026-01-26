import Fixtures
import Testing

@testable import ShapeTree
@testable import Wayland

@MainActor
@Suite struct GrowTests {

  @Test
  func basicGrow() {
    let containerWidth: UInt = 600
    let containerHeight: UInt = 400
    let test = GrowTestBasic()

    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    test.walk(with: &sizer)

    // Set the root container size (simulating what Wayland.render does)
    let rootId = attributesWalker.tree[0]![0]
    let orientation: Orientation
    switch sizer.sizes[rootId]! {
    case .known(let container):
      orientation = container.orientation
    case .unknown(let o):
      orientation = o
    }
    sizer.sizes[rootId] = .known(Container(height: containerHeight, width: containerWidth, orientation: orientation))

    let containers = sizer.sizes.convert()
    var grower = GrowWalker(sizes: containers, attributes: attributesWalker.attributes)
    test.walk(with: &grower)

    let growElement = attributesWalker.tree[rootId]![0]

    if let grownSize = grower.sizes[growElement] {
      #expect(grownSize.width == containerWidth)
      #expect(grownSize.height == containerHeight)
    } else {
      Issue.record("Grow element not found in grower.sizes")
    }
  }

  @Test
  func growWithFixedParent() {
    // BUG: I think this test is wrong
    let test = GrowTestWithFixedParent()

    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    test.walk(with: &sizer)

    let containers = sizer.sizes.convert()
    var grower = GrowWalker(sizes: containers, attributes: attributesWalker.attributes)
    test.walk(with: &grower)

    let rootId = attributesWalker.tree[0]![0]
    let directionGroup = attributesWalker.tree[rootId]![0]
    let tupleBlock = attributesWalker.tree[directionGroup]![0]
    let children = attributesWalker.tree[tupleBlock]!

    guard children.count >= 2 else {
      Issue.record("Expected at least 2 children, got \(children.count)")
      return
    }
    let fixedRect = children[0]
    let growRect = children[1]

    if let fixedSize = grower.sizes[fixedRect] {
      #expect(fixedSize.width == 200)
      #expect(fixedSize.height == 100)
    } else {
      Issue.record("Fixed rect not found in grower.sizes")
    }

    if let growSize = grower.sizes[growRect] {
      #expect(growSize.width == 200)
      #expect(growSize.height == 100)
    } else {
      Issue.record("Grow rect not found in grower.sizes")
    }
  }
}
