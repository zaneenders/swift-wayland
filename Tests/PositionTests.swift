import Testing

@testable import Wayland

@MainActor
@Suite
struct PositionTests {

  @Test("Horizontal positioning")
  func positionHorizontal() {
    let test = PositionTestSimpleHorizontal()
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker()
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
    // Second rect should be at (50, 0) - to the right (10 * scale 5)
    #expect(rectPositions[1] == (x: 50, y: 0))
    // Third rect should be at (100, 0) - further right (10 * scale 5 * 2)
    #expect(rectPositions[2] == (x: 100, y: 0))
  }

  @Test("Vertical positioning")
  func positionVertical() {
    let test = PositionTestSimpleVertical()
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker()
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
  }

  @Test("Zero size rectangle")
  func edgeCaseZeroSize() {
    let test = EdgeCaseZeroSize()
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker()
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
    var sizer = SizeWalker()
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
}

struct PositionTestSimpleHorizontal: Block {
  let scale: UInt = 5
  var layer: some Block {
    Direction(.horizontal) {
      Rect()
        .width(10)
        .height(10)
        .background(.red)
        .scale(scale)
      Rect()
        .width(10)
        .height(10)
        .background(.blue)
        .scale(scale)
      Rect()
        .width(10)
        .height(10)
        .background(.green)
        .scale(scale)
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
        .scale(1)
      Rect()
        .width(10)
        .height(10)
        .background(.blue)
        .scale(1)
      Rect()
        .width(10)
        .height(10)
        .background(.green)
        .scale(1)
    }
  }
}

struct EdgeCaseZeroSize: Block {
  var layer: some Block {
    Rect()
      .width(0)
      .height(0)
      .background(.red)
      .scale(1)
  }
}

struct EdgeCaseVeryLarge: Block {
  var layer: some Block {
    Rect()
      .width(UInt.max / 2)
      .height(UInt.max / 2)
      .background(.red)
      .scale(1)
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
              .scale(1)
          }
        }
      }
    }
  }
}
