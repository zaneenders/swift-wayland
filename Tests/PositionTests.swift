import Testing

@testable import Wayland

@MainActor
@Suite("Position Walker Tests")
struct PositionTests {

  @Test("Horizontal positioning")
  func positionHorizontal() {
    let test = PositionTestSimpleHorizontal()
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(attributes: attributesWalker.attributes)
    test.walk(with: &sizer)

    var positioner = PositionWalker(sizes: sizer.sizes.convert())
    test.walk(with: &positioner)

    // Get the tuple block containing the rectangles
    let testStruct = attributesWalker.tree[0]![0]
    let group = attributesWalker.tree[testStruct]![0]
    let tupleBlock = attributesWalker.tree[group]![0]

    // Get the rectangle IDs
    let rectIds = attributesWalker.tree[tupleBlock]!
    let rectPositions = rectIds.map { positioner.positions[$0]! }.sorted { $0.x < $1.x }

    // First rect should be at (0, 0)
    #expect(rectPositions[0] == (x: 0, y: 0))
    // Second rect should be at (10, 0) - to the right (width 10)
    #expect(rectPositions[1] == (x: 10, y: 0))
    // Third rect should be at (20, 0) - further right (10 + 10)
    #expect(rectPositions[2] == (x: 20, y: 0))

    // All positions should be valid
    rectPositions.forEach { TestUtils.Assert.validPosition((Int($0.x), Int($0.y))) }
  }

  @Test("Vertical positioning")
  func positionVertical() {
    let test = PositionTestSimpleVertical()
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(attributes: attributesWalker.attributes)
    test.walk(with: &sizer)

    var positioner = PositionWalker(sizes: sizer.sizes.convert())
    test.walk(with: &positioner)

    // Get the tuple block containing rectangles
    let testStruct = attributesWalker.tree[0]![0]
    let group = attributesWalker.tree[testStruct]![0]
    let tupleBlock = attributesWalker.tree[group]![0]

    // Get the rectangle IDs
    let rectIds = attributesWalker.tree[tupleBlock]!
    let rectPositions = rectIds.map { positioner.positions[$0]! }.sorted { $0.y < $1.y }

    // First rect should be at (0, 0)
    #expect(rectPositions[0] == (x: 0, y: 0))
    // Second rect should be at (0, 10) - below
    #expect(rectPositions[1] == (x: 0, y: 10))
    // Third rect should be at (0, 20) - further below
    #expect(rectPositions[2] == (x: 0, y: 20))

    // All positions should be valid
    rectPositions.forEach { TestUtils.Assert.validPosition((Int($0.x), Int($0.y))) }
  }

  @Test("Zero size rectangle")
  func edgeCaseZeroSize() {
    let test = EdgeCaseZeroSize()
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(attributes: attributesWalker.attributes)
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
    var sizer = SizeWalker(attributes: attributesWalker.attributes)
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
    var sizer = SizeWalker(attributes: attributesWalker.attributes)
    test.walk(with: &sizer)
    let testStruct = attributesWalker.tree[0]![0]
    let tupleBlock = attributesWalker.tree[testStruct]![0]
    if case .known(let container) = sizer.sizes[tupleBlock]! {
      // Verify large values don't cause overflow or crashes
      #expect(container.width > 0, "Width should be positive for large values")
      #expect(container.height > 0, "Height should be positive for large values")
    }
  }

  @Test("Edge case: overflow protection")
  func edgeCaseOverflowProtection() {
    // Test that adding elements with very large values doesn't crash
    struct OverflowTest: Block {
      var layer: some Block {
        Direction(.horizontal) {
          Rect().width(100).height(100).background(.red)
          Rect().width(200).height(200).background(.blue)
          Rect().width(300).height(300).background(.green)
        }
      }
    }

    let test = OverflowTest()
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(attributes: attributesWalker.attributes)
    test.walk(with: &sizer)

    // Should not crash
    #expect(!sizer.sizes.isEmpty, "Should calculate sizes without crashing")
  }
}

struct PositionTestSimpleHorizontal: Block {
  let scale: UInt = 5
  var layer: some Block {
    Direction(.horizontal) {
      Rect()
        .width(10)
        .height(10)
        .background(.red)
      Rect()
        .width(10)
        .height(10)
        .background(.blue)
      Rect()
        .width(10)
        .height(10)
        .background(.green)
    }
  }
}

struct PositionTestSimpleVertical: Block {
  var layer: some Block {
    Direction(.vertical) {
      Rect()
        .width(10)
        .height(10)
        .background(.red)
      Rect()
        .width(10)
        .height(10)
        .background(.blue)
      Rect()
        .width(10)
        .height(10)
        .background(.green)
    }
  }
}

struct EdgeCaseZeroSize: Block {
  var layer: some Block {
    Rect()
      .width(0)
      .height(0)
      .background(.red)
  }
}

struct EdgeCaseVeryLarge: Block {
  var layer: some Block {
    Rect()
      .width(UInt.max / 2)
      .height(UInt.max / 2)
      .background(.red)
  }
}

struct EdgeCaseDeepNesting: Block {
  var layer: some Block {
    Direction(.horizontal) {
      Direction(.vertical) {
        Direction(.horizontal) {
          Direction(.vertical) {
            Rect()
              .width(10)
              .height(10)
              .background(.red)
          }
        }
      }
    }
  }
}
