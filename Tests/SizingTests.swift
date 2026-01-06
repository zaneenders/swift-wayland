import Testing

@testable import Wayland

@MainActor
@Suite
struct SizingTests {
  @Test("Basic Rectangle sizing")
  func rectBasicSizing() {
    let scale: UInt = 2
    let test = RectTestBasic(scale: scale)
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(attributes: attributesWalker.attributes)
    test.walk(with: &sizer)
    let testStruct = attributesWalker.tree[0]![0]
    let tupleBlock = attributesWalker.tree[testStruct]![0]
    #expect(
      sizer.sizes[tupleBlock]! == Size.known(Container(height: scale * 50, width: scale * 100, orientation: .vertical)))
  }

  @Test("Multiple Rectangle horizontal layout")
  func rectMultipleHorizontal() {
    let test = RectTestMultiple()
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(attributes: attributesWalker.attributes)
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

  @Test("Nested Rectangle layout")
  func rectNestedLayout() {
    let test = RectTestNested()
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(attributes: attributesWalker.attributes)
    test.walk(with: &sizer)
    let testStruct = attributesWalker.tree[0]![0]
    let group = attributesWalker.tree[testStruct]![0]
    let tupleBlock = attributesWalker.tree[group]![0]
    // Vertical: 20 + max(30, 30) + 20 = 70, Width: max(100, 60, 100) = 100
    #expect(sizer.sizes[tupleBlock]! == Size.known(Container(height: 70, width: 100, orientation: .vertical)))
  }

  @Test("Rectangle scaling")
  func rectScaling() {
    let test = RectTestScaled()
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(attributes: attributesWalker.attributes)
    test.walk(with: &sizer)
    let testStruct = attributesWalker.tree[0]![0]
    let group = attributesWalker.tree[testStruct]![0]
    let tupleBlock = attributesWalker.tree[group]![0]
    // Width: 10 + 10 + 10 = 30, Height: max(10, 10, 10) = 10 (scale is Text-only now)
    #expect(sizer.sizes[tupleBlock]! == Size.known(Container(height: 10, width: 30, orientation: .horizontal)))
  }

  @Test("Empty group sizing")
  func spacingEmptyGroup() {
    let test = SpacingTestEmptyGroup()
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(attributes: attributesWalker.attributes)
    test.walk(with: &sizer)
    let testStruct = attributesWalker.tree[0]![0]
    let group = attributesWalker.tree[testStruct]![0]
    let tupleBlock = attributesWalker.tree[group]![0]
    #expect(sizer.sizes[tupleBlock]! == Size.known(Container(height: 0, width: 0, orientation: .horizontal)))
  }

  @Test("Single element group")
  func spacingSingleElement() {
    let test = SpacingTestSingleElement()
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(attributes: attributesWalker.attributes)
    test.walk(with: &sizer)
    let testStruct = attributesWalker.tree[0]![0]
    let group = attributesWalker.tree[testStruct]![0]
    let tupleBlock = attributesWalker.tree[group]![0]
    if case .known(let container) = sizer.sizes[tupleBlock]! {
      #expect(container.height > 0)
      #expect(container.width > 0)
    }
  }

  @Test("Mixed Word and Rectangle spacing")
  func spacingWordRectMixed() {
    let test = SpacingTestWordRectMixed(scale: 1)
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(attributes: attributesWalker.attributes)
    test.walk(with: &sizer)
    let testStruct = attributesWalker.tree[0]![0]
    let group = attributesWalker.tree[testStruct]![0]
    let tupleBlock = attributesWalker.tree[group]![0]
    #expect(sizer.sizes[tupleBlock]! == Size.known(Container(height: 20, width: 78, orientation: .horizontal)))
  }

  @Test("Complex nesting spacing")
  func spacingComplexNesting() {
    let test = SpacingTestComplexNesting()
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(attributes: attributesWalker.attributes)
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

  @Test("Large size differences")
  func spacingLargeGap() {
    let test = SpacingTestLargeGap()
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(attributes: attributesWalker.attributes)
    test.walk(with: &sizer)
    let testStruct = attributesWalker.tree[0]![0]
    let group = attributesWalker.tree[testStruct]![0]
    let tupleBlock = attributesWalker.tree[group]![0]
    // Width: 5 + 100 + 5 = 110, Height: max(5, 100, 5) = 100
    #expect(sizer.sizes[tupleBlock]! == Size.known(Container(height: 100, width: 110, orientation: .horizontal)))
  }

  @Test("Basic Rectangle scaling")
  func basicRectangleScaling() {
    let scale: UInt = 2
    let test = RectTestBasic(scale: scale)
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(attributes: attributesWalker.attributes)
    test.walk(with: &sizer)
    let testStruct = attributesWalker.tree[0]![0]
    let tupleBlock = attributesWalker.tree[testStruct]![0]

    if case .known(let container) = sizer.sizes[tupleBlock]! {
      #expect(container.height == scale * 50)
      #expect(container.width == scale * 100)
    }
  }

  @Test("Multiple Rectangle scaling")
  func multipleRectangleScaling() {
    let test = RectTestScaled()
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(attributes: attributesWalker.attributes)
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

  @Test("Quad scaling verification")
  func quadScaling() {
    let test = QuadTestScaling()
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(attributes: attributesWalker.attributes)
    test.walk(with: &sizer)

    var positioner = PositionWalker(sizes: sizer.sizes.convert(), attributes: attributesWalker.attributes)
    test.walk(with: &positioner)

    // Reset renderer and capture quads
    QuadCaptureRenderer.reset()
    var renderWalker = RenderWalker(
      positions: positioner.positions, sizes: sizer.sizes.convert(), QuadCaptureRenderer.self, logLevel: .error)
    test.walk(with: &renderWalker)

    // Filter out 0x0 quads (from empty containers)
    let nonZeroQuads = QuadCaptureRenderer.capturedQuads.filter {
      $0.width > 0 && $0.height > 0
    }

    // Verify we captured 3 non-zero quads
    #expect(nonZeroQuads.count == 3)

    // Sort by width to get predictable order
    let quads = nonZeroQuads.sorted { $0.width < $1.width }

    // Verify rectangle dimensions (no scaling for Rect)
    #expect(quads[0].width == 10)
    #expect(quads[0].height == 10)
    #expect(quads[1].width == 10)
    #expect(quads[1].height == 10)
    #expect(quads[2].width == 10)
    #expect(quads[2].height == 10)
  }

  @Test func scaledText() {
    let scale: UInt = 16
    let block = ScaledText(scale: scale)

    var attributesWalker = AttributesWalker()
    block.walk(with: &attributesWalker)
    var sizer = SizeWalker(attributes: attributesWalker.attributes)
    block.walk(with: &sizer)

    let testStruct = attributesWalker.tree[0]![0]
    let attributedBlock = attributesWalker.tree[testStruct]![0]

    if case .known(let container) = sizer.sizes[attributedBlock]! {
      #expect(container.width == 29 * scale)
      #expect(container.height == 7 * scale)
      #expect(container.orientation == .vertical)
    }
  }

  @Test func textRenderingWithScale() {
    let block = TextTestScaling()

    var attributesWalker = AttributesWalker()
    block.walk(with: &attributesWalker)
    var sizer = SizeWalker(attributes: attributesWalker.attributes)
    block.walk(with: &sizer)

    var positioner = PositionWalker(sizes: sizer.sizes.convert(), attributes: attributesWalker.attributes)
    block.walk(with: &positioner)

    // Reset renderer and capture text
    TextCaptureRenderer.reset()
    var renderWalker = RenderWalker(
      positions: positioner.positions, sizes: sizer.sizes.convert(), TextCaptureRenderer.self, logLevel: .error)
    block.walk(with: &renderWalker)

    // Verify we captured 3 text items
    #expect(TextCaptureRenderer.capturedTexts.count == 3)

    // Sort by scale to get predictable order
    let texts = TextCaptureRenderer.capturedTexts.sorted { $0.scale < $1.scale }

    // Verify scale is correctly applied
    #expect(texts[0].scale == 1)
    #expect(texts[0].text == "Small")
    #expect(texts[1].scale == 1)  // No explicit scale set
    #expect(texts[1].text == "Medium")
    #expect(texts[2].scale == 1)  // No explicit scale set
    #expect(texts[2].text == "Large")

    // Verify colors are applied
    #expect(texts[0].forground == .red)
    #expect(texts[1].forground == .green)
    #expect(texts[2].forground == .blue)
  }
}

struct ScaledText: Block {
  let scale: UInt
  var layer: some Block {
    Text("Hello")
      .scale(scale)
  }
}

struct RectTestMultiple: Block {
  var layer: some Block {
    Direction(.horizontal) {
      Rect()
        .width(50)
        .height(30)
        .background(.red)
      Rect()
        .width(40)
        .height(60)
        .background(.blue)
      Rect()
        .width(30)
        .height(40)
        .background(.green)
    }
  }
}

struct RectTestNested: Block {
  var layer: some Block {
    Direction(.vertical) {
      Rect()
        .width(100)
        .height(20)
        .background(.red)
      Direction(.horizontal) {
        Rect()
          .width(30)
          .height(30)
          .background(.blue)
        Rect()
          .width(30)
          .height(30)
          .background(.green)
      }
      Rect()
        .width(100)
        .height(20)
        .background(.yellow)
    }
  }
}

struct SpacingTestEmptyGroup: Block {
  var layer: some Block {
    Direction(.horizontal) {}
  }
}

struct SpacingTestSingleElement: Block {
  var layer: some Block {
    Direction(.horizontal) {
      Text("Single")
    }
  }
}

struct SpacingTestWordRectMixed: Block {
  let scale: UInt
  var layer: some Block {
    Direction(.horizontal) {
      Text("Hello")
        .scale(scale)
      Rect()
        .width(20 * scale)
        .height(20 * scale)
        .background(.red)
      Text("World")
        .scale(scale)
    }
  }
}

struct SpacingTestComplexNesting: Block {
  var layer: some Block {
    Direction(.vertical) {
      Text("Top")
      Direction(.horizontal) {
        Rect()
          .width(15)
          .height(15)
          .background(.red)
        Text("Middle")
        Rect()
          .width(15)
          .height(15)
          .background(.blue)
      }
      Direction(.horizontal) {
        Rect()
          .width(10)
          .height(10)
          .background(.green)
        Rect()
          .width(10)
          .height(10)
          .background(.yellow)
      }
      Text("Bottom")
    }
  }
}

struct SpacingTestLargeGap: Block {
  var layer: some Block {
    Direction(.horizontal) {
      Rect()
        .width(5)
        .height(5)
        .background(.red)
      Rect()
        .width(100)
        .height(100)
        .background(.green)
      Rect()
        .width(5)
        .height(5)
        .background(.blue)
    }
  }
}

struct QuadTestScaling: Block {
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

struct RectTestBasic: Block {
  var scale: UInt = 1
  var layer: some Block {
    Rect()
      .width(100 * scale)
      .height(50 * scale)
      .background(.red)
  }
}

struct RectTestScaled: Block {
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

struct TextTestScaling: Block {
  var layer: some Block {
    Direction(.horizontal) {
      Text("Small")
        .foreground(.red)
      Text("Medium")
        .foreground(.green)
      Text("Large")
        .foreground(.blue)
    }
  }
}

enum TextCaptureRenderer: Renderer {
  static var capturedTexts: [RenderableText] = []

  static func drawQuad(_ quad: RenderableQuad) {}

  static func drawText(_ text: RenderableText) {
    capturedTexts.append(text)
  }

  static func reset() {
    capturedTexts.removeAll()
  }
}

enum QuadCaptureRenderer: Renderer {
  static var capturedQuads: [RenderableQuad] = []

  static func drawQuad(_ quad: RenderableQuad) {

    capturedQuads.append(quad)
  }

  static func drawText(_ text: RenderableText) {}

  static func reset() {
    capturedQuads.removeAll()
  }
}
