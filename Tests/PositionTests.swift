import Fixtures
import Testing

@testable import ShapeTree
@testable import SwiftWayland
@testable import Wayland

@MainActor
@Suite("Position Walker Tests")
struct PositionTests {

  @Test("Horizontal positioning")
  func positionHorizontal() {
    let test = PositionTestSimpleHorizontal()
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    test.walk(with: &sizer)

    var positioner = PositionWalker(sizes: sizer.sizes.convert(), attributes: attributesWalker.attributes)
    test.walk(with: &positioner)

    let testStruct = attributesWalker.tree[0]![0]
    let group = attributesWalker.tree[testStruct]![0]
    let tupleBlock = attributesWalker.tree[group]![0]

    let rectIds = attributesWalker.tree[tupleBlock]!
    let rectPositions = rectIds.map { positioner.positions[$0]! }.sorted { $0.x < $1.x }

    #expect(rectPositions[0] == (x: 0, y: 0))
    #expect(rectPositions[1] == (x: 10, y: 0))
    #expect(rectPositions[2] == (x: 20, y: 0))

    rectPositions.forEach { TestUtils.Assert.validPosition((Int($0.x), Int($0.y))) }
  }

  @Test("Vertical positioning")
  func positionVertical() {
    let test = PositionTestSimpleVertical()
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    test.walk(with: &sizer)

    var positioner = PositionWalker(sizes: sizer.sizes.convert(), attributes: attributesWalker.attributes)
    test.walk(with: &positioner)

    let testStruct = attributesWalker.tree[0]![0]
    let group = attributesWalker.tree[testStruct]![0]
    let tupleBlock = attributesWalker.tree[group]![0]

    let rectIds = attributesWalker.tree[tupleBlock]!
    let rectPositions = rectIds.map { positioner.positions[$0]! }.sorted { $0.y < $1.y }

    #expect(rectPositions[0] == (x: 0, y: 0))
    #expect(rectPositions[1] == (x: 0, y: 10))
    #expect(rectPositions[2] == (x: 0, y: 20))

    rectPositions.forEach { TestUtils.Assert.validPosition((Int($0.x), Int($0.y))) }
  }

  @Test("Zero size rectangle")
  func edgeCaseZeroSize() {
    let test = EdgeCaseZeroSize()
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    test.walk(with: &sizer)
    let testStruct = attributesWalker.tree[0]![0]
    let tupleBlock = attributesWalker.tree[testStruct]![0]
    #expect(sizer.sizes[tupleBlock]! == .known(Container(height: 0, width: 0, orientation: .vertical)))
  }

  @Test("Deep nesting")
  func edgeCaseDeepNesting() {
    let test = EdgeCaseDeepNesting()
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    test.walk(with: &sizer)
    let testStruct = attributesWalker.tree[0]![0]
    let group1 = attributesWalker.tree[testStruct]![0]
    let group2 = attributesWalker.tree[group1]![0]
    let group3 = attributesWalker.tree[group2]![0]
    let group4 = attributesWalker.tree[group3]![0]
    let tupleBlock = attributesWalker.tree[group4]![0]
    if case .known(let container) = sizer.sizes[tupleBlock]! {
      #expect(container.height == 10)
      #expect(container.width == 10)
    }
  }

  @Test("Edge case: very large values")
  func edgeCaseVeryLarge() {
    let test = EdgeCaseVeryLarge()
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    test.walk(with: &sizer)
    let testStruct = attributesWalker.tree[0]![0]
    let tupleBlock = attributesWalker.tree[testStruct]![0]
    if case .known(let container) = sizer.sizes[tupleBlock]! {
      #expect(container.width > 0, "Width should be positive for large values")
      #expect(container.height > 0, "Height should be positive for large values")
    }
  }

  @Test("Edge case: overflow protection")
  func edgeCaseOverflowProtection() {
    struct OverflowTest: Block {
      var layer: some Block {
        Direction(.horizontal) {
          Rect().width(.fixed(100)).height(.fixed(100)).background(.red)
          Rect().width(.fixed(200)).height(.fixed(200)).background(.blue)
          Rect().width(.fixed(300)).height(.fixed(300)).background(.green)
        }
      }
    }

    let test = OverflowTest()
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    test.walk(with: &sizer)

    #expect(!sizer.sizes.isEmpty, "Should calculate sizes without crashing")
  }
}

@Test
@MainActor
func leftPaddingTest() {
  let block = LeftPadding()
  let layout = calculateLayout(block)
  // TODO: write test
  print(layout)
}
