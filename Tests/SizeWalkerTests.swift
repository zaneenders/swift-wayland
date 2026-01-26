import Fixtures
import Testing

@testable import ShapeTree
@testable import Wayland

@MainActor
@Suite struct SizeWalkerTests {

  @Test
  func rectBasicSizing() {
    let scale: UInt = 2
    let block = RectTestBasic(scale: scale)
    var attributesWalker = AttributesWalker()
    block.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    block.walk(with: &sizer)

    let testStruct = attributesWalker.tree[0]![0]
    let tupleBlock = attributesWalker.tree[testStruct]![0]
    #expect(
      sizer.sizes[tupleBlock]! == Size.known(Container(height: scale * 50, width: scale * 100, orientation: .vertical)))
  }

  @Test
  func rectMultipleHorizontal() {
    let block = RectTestMultiple()
    var attributesWalker = AttributesWalker()
    block.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    block.walk(with: &sizer)

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
    let block = RectTestNested()
    var attributesWalker = AttributesWalker()
    block.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    block.walk(with: &sizer)
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
    let block = SpacingTestSingleElement()
    var attributesWalker = AttributesWalker()
    block.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    block.walk(with: &sizer)
    let testStruct = attributesWalker.tree[0]![0]
    let group = attributesWalker.tree[testStruct]![0]
    let tupleBlock = attributesWalker.tree[group]![0]
    if case .known(let container) = sizer.sizes[tupleBlock]! {
      #expect(container.height == 7)
      #expect(container.width == 35)
    } else {
      Issue.record("unknown")
    }
  }

  @Test
  func spacingWordRectMixed() {
    let block = SpacingTestWordRectMixed(scale: 1)
    var attributesWalker = AttributesWalker()
    block.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    block.walk(with: &sizer)
    let testStruct = attributesWalker.tree[0]![0]
    let group = attributesWalker.tree[testStruct]![0]
    let tupleBlock = attributesWalker.tree[group]![0]
    #expect(sizer.sizes[tupleBlock]! == Size.known(Container(height: 20, width: 78, orientation: .horizontal)))
  }

  @Test
  func spacingComplexNesting() {
    let block = SpacingTestComplexNesting()
    var attributesWalker = AttributesWalker()
    block.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    block.walk(with: &sizer)
    let testStruct = attributesWalker.tree[0]![0]
    let group = attributesWalker.tree[testStruct]![0]
    let tupleBlock = attributesWalker.tree[group]![0]
    if case .known(let container) = sizer.sizes[tupleBlock]! {
      #expect(container.height == 39)
      #expect(container.width == 65)
    } else {
      Issue.record("unknown")
    }
  }

  @Test
  func spacingLargeGap() {
    let block = SpacingTestLargeGap()
    var attributesWalker = AttributesWalker()
    block.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    block.walk(with: &sizer)
    let testStruct = attributesWalker.tree[0]![0]
    let group = attributesWalker.tree[testStruct]![0]
    let tupleBlock = attributesWalker.tree[group]![0]
    // Width: 5 + 100 + 5 = 110, Height: max(5, 100, 5) = 100
    #expect(sizer.sizes[tupleBlock]! == Size.known(Container(height: 100, width: 110, orientation: .horizontal)))
  }

  @Test
  func basicRectangleScaling() {
    let scale: UInt = 2
    let block = RectTestBasic(scale: scale)
    var attributesWalker = AttributesWalker()
    block.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    block.walk(with: &sizer)
    let testStruct = attributesWalker.tree[0]![0]
    let tupleBlock = attributesWalker.tree[testStruct]![0]
    if case .known(let container) = sizer.sizes[tupleBlock]! {
      #expect(container.height == scale * 50)
      #expect(container.width == scale * 100)
    } else {
      Issue.record("unknown")
    }
  }

  @Test
  func multipleRectangleScaling() {
    let block = RectTestScaled()
    var attributesWalker = AttributesWalker()
    block.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    block.walk(with: &sizer)
    let testStruct = attributesWalker.tree[0]![0]
    let group = attributesWalker.tree[testStruct]![0]
    let tupleBlock = attributesWalker.tree[group]![0]
    // Width: 10 + 10 + 10 = 30, Height: max(10, 10, 10) = 10 (scale is Text-only now)
    if case .known(let container) = sizer.sizes[tupleBlock]! {
      #expect(container.height == 10)
      #expect(container.width == 30)
    } else {
      Issue.record("unknown")
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
    } else {
      Issue.record("unknown")
    }
  }
}
