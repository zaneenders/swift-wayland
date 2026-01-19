import Fixtures
import Testing

@testable import ShapeTree
@testable import Wayland

@MainActor
@Suite
struct SizingTests {

  @Test
  func rectBasicSizing() {
    let scale: UInt = 2
    let test = RectTestBasic(scale: scale)
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    test.walk(with: &sizer)
    let testStruct = attributesWalker.tree[0]![0]
    let tupleBlock = attributesWalker.tree[testStruct]![0]
    #expect(
      sizer.sizes[tupleBlock]! == Size.known(Container(height: scale * 50, width: scale * 100, orientation: .vertical)))
  }

  @Test
  func rectMultipleHorizontal() {
    let test = RectTestMultiple()
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    test.walk(with: &sizer)

    // Navigate to the actual group containing the rectangles
    let testStruct = attributesWalker.tree[0]![0]  // RectTestMultiple
    let group = attributesWalker.tree[testStruct]![0]  // Group(.horizontal)
    let tupleBlock = attributesWalker.tree[group]![0]  // _TupleBlock containing rectangles

    // Width: 50 + 40 + 30 = 120, Height: max(30, 60, 40) = 60
    if case .known(let container) = sizer.sizes[tupleBlock]! {
      #expect(container.orientation == .horizontal)
      #expect(container.height == 60)
      #expect(container.width == 120)
    }
  }

  @Test
  func rectNestedLayout() {
    let test = RectTestNested()
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    test.walk(with: &sizer)
    let testStruct = attributesWalker.tree[0]![0]
    let group = attributesWalker.tree[testStruct]![0]
    let tupleBlock = attributesWalker.tree[group]![0]
    // Vertical: 20 + max(30, 30) + 20 = 70, Width: max(100, 60, 100) = 100
    #expect(sizer.sizes[tupleBlock]! == Size.known(Container(height: 70, width: 100, orientation: .vertical)))
  }

  @Test
  func rectScaling() {
    let test = RectTestScaled()
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    test.walk(with: &sizer)
    let testStruct = attributesWalker.tree[0]![0]
    let group = attributesWalker.tree[testStruct]![0]
    let tupleBlock = attributesWalker.tree[group]![0]
    // Width: 10 + 10 + 10 = 30, Height: max(10, 10, 10) = 10 (scale is Text-only now)
    #expect(sizer.sizes[tupleBlock]! == Size.known(Container(height: 10, width: 30, orientation: .horizontal)))
  }

  @Test
  func spacingEmptyGroup() {
    let test = SpacingTestEmptyGroup()
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    test.walk(with: &sizer)
    let testStruct = attributesWalker.tree[0]![0]
    let group = attributesWalker.tree[testStruct]![0]
    let tupleBlock = attributesWalker.tree[group]![0]
    #expect(sizer.sizes[tupleBlock]! == Size.known(Container(height: 0, width: 0, orientation: .horizontal)))
  }

  @Test
  func spacingSingleElement() {
    let test = SpacingTestSingleElement()
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    test.walk(with: &sizer)
    let testStruct = attributesWalker.tree[0]![0]
    let group = attributesWalker.tree[testStruct]![0]
    let tupleBlock = attributesWalker.tree[group]![0]
    if case .known(let container) = sizer.sizes[tupleBlock]! {
      #expect(container.height > 0)
      #expect(container.width > 0)
    }
  }

  @Test
  func spacingWordRectMixed() {
    let test = SpacingTestWordRectMixed(scale: 1)
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    test.walk(with: &sizer)
    let testStruct = attributesWalker.tree[0]![0]
    let group = attributesWalker.tree[testStruct]![0]
    let tupleBlock = attributesWalker.tree[group]![0]
    #expect(sizer.sizes[tupleBlock]! == Size.known(Container(height: 20, width: 78, orientation: .horizontal)))
  }

  @Test
  func spacingComplexNesting() {
    let test = SpacingTestComplexNesting()
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    test.walk(with: &sizer)
    let testStruct = attributesWalker.tree[0]![0]
    let group = attributesWalker.tree[testStruct]![0]
    let tupleBlock = attributesWalker.tree[group]![0]
    // This is a complex test - we mainly verify it doesn't crash and produces reasonable results
    if case .known(let container) = sizer.sizes[tupleBlock]! {
      #expect(container.height > 0)
      #expect(container.width > 0)
    }
  }

  @Test
  func spacingLargeGap() {
    let test = SpacingTestLargeGap()
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    test.walk(with: &sizer)
    let testStruct = attributesWalker.tree[0]![0]
    let group = attributesWalker.tree[testStruct]![0]
    let tupleBlock = attributesWalker.tree[group]![0]
    // Width: 5 + 100 + 5 = 110, Height: max(5, 100, 5) = 100
    #expect(sizer.sizes[tupleBlock]! == Size.known(Container(height: 100, width: 110, orientation: .horizontal)))
  }

  @Test
  func basicRectangleScaling() {
    let scale: UInt = 2
    let test = RectTestBasic(scale: scale)
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    test.walk(with: &sizer)
    let testStruct = attributesWalker.tree[0]![0]
    let tupleBlock = attributesWalker.tree[testStruct]![0]

    if case .known(let container) = sizer.sizes[tupleBlock]! {
      #expect(container.height == scale * 50)
      #expect(container.width == scale * 100)
    }
  }

  @Test
  func multipleRectangleScaling() {
    let test = RectTestScaled()
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    test.walk(with: &sizer)
    let testStruct = attributesWalker.tree[0]![0]
    let group = attributesWalker.tree[testStruct]![0]
    let tupleBlock = attributesWalker.tree[group]![0]

    // Width: 10 + 10 + 10 = 30, Height: max(10, 10, 10) = 10 (scale is Text-only now)
    if case .known(let container) = sizer.sizes[tupleBlock]! {
      #expect(container.height == 10)
      #expect(container.width == 30)
    }
  }

  @Test func scaledText() {
    let scale: UInt = 16
    let block = ScaledText(scale: scale)

    var attributesWalker = AttributesWalker()
    block.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    block.walk(with: &sizer)

    let testStruct = attributesWalker.tree[0]![0]
    let attributedBlock = attributesWalker.tree[testStruct]![0]

    if case .known(let container) = sizer.sizes[attributedBlock]! {
      #expect(container.width == 29 * scale)
      #expect(container.height == 7 * scale)
      #expect(container.orientation == .vertical)
    }
  }

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

    // Apply grow sizing
    let containers = sizer.sizes.convert()
    var grower = GrowWalker(sizes: containers, attributes: attributesWalker.attributes)
    test.walk(with: &grower)

    // Navigate to the grow element
    let growElement = attributesWalker.tree[rootId]![0]

    // Verify the grow element fills the container
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
