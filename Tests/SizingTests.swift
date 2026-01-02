import Testing

@testable import Wayland

@MainActor
@Suite
struct SizingTests {

  @Test("Basic Rectangle sizing")
  func rectBasicSizing() {
    var sizer = SizeWalker()
    let scale: UInt = 2
    let test = RectTestBasic(scale: scale)
    test.walk(with: &sizer)
    let testStruct = sizer.tree[0]![0]
    let tupleBlock = sizer.tree[testStruct]![0]
    #expect(
      sizer.sizes[tupleBlock]! == .known(Container(height: scale * 50, width: scale * 100, orientation: .vertical)))
  }

  @Test("Multiple Rectangle horizontal layout")
  func rectMultipleHorizontal() {
    var sizer = SizeWalker()
    let test = RectTestMultiple()
    test.walk(with: &sizer)

    // Navigate to the actual group containing the rectangles
    let testStruct = sizer.tree[0]![0]  // RectTestMultiple
    let group = sizer.tree[testStruct]![0]  // Group(.horizontal)
    let tupleBlock = sizer.tree[group]![0]  // _TupleBlock containing rectangles

    // Width: 50 + 40 + 30 = 120, Height: max(30, 60, 40) = 60
    if case .known(let container) = sizer.sizes[tupleBlock]! {
      #expect(container.orientation == .horizontal)
      #expect(container.height == 60)
      #expect(container.width == 120)
    }
  }

  @Test("Nested Rectangle layout")
  func rectNestedLayout() {
    var sizer = SizeWalker()
    let test = RectTestNested()
    test.walk(with: &sizer)
    let testStruct = sizer.tree[0]![0]
    let group = sizer.tree[testStruct]![0]
    let tupleBlock = sizer.tree[group]![0]
    // Vertical: 20 + max(30, 30) + 20 = 70, Width: max(100, 60, 100) = 100
    #expect(sizer.sizes[tupleBlock]! == .known(Container(height: 70, width: 100, orientation: .vertical)))
  }

  @Test("Rectangle scaling")
  func rectScaling() {
    var sizer = SizeWalker()
    let test = RectTestScaled()
    test.walk(with: &sizer)
    let testStruct = sizer.tree[0]![0]
    let group = sizer.tree[testStruct]![0]
    let tupleBlock = sizer.tree[group]![0]
    // Width: 10*1 + 10*2 + 10*3 = 60, Height: max(10*1, 10*2, 10*3) = 30
    #expect(sizer.sizes[tupleBlock]! == .known(Container(height: 30, width: 60, orientation: .horizontal)))
  }

  @Test("Empty group sizing")
  func spacingEmptyGroup() {
    var sizer = SizeWalker()
    let test = SpacingTestEmptyGroup()
    test.walk(with: &sizer)
    let testStruct = sizer.tree[0]![0]
    let group = sizer.tree[testStruct]![0]
    let tupleBlock = sizer.tree[group]![0]
    #expect(sizer.sizes[tupleBlock]! == .known(Container(height: 0, width: 0, orientation: .horizontal)))
  }

  @Test("Single element group")
  func spacingSingleElement() {
    var sizer = SizeWalker()
    let test = SpacingTestSingleElement()
    test.walk(with: &sizer)
    let testStruct = sizer.tree[0]![0]
    let group = sizer.tree[testStruct]![0]
    let tupleBlock = sizer.tree[group]![0]
    if case .known(let container) = sizer.sizes[tupleBlock]! {
      #expect(container.height > 0)
      #expect(container.width > 0)
    }
  }

  @Test("Mixed Word and Rectangle spacing")
  func spacingWordRectMixed() {
    var sizer = SizeWalker()
    let test = SpacingTestWordRectMixed()
    test.walk(with: &sizer)
    let testStruct = sizer.tree[0]![0]
    let group = sizer.tree[testStruct]![0]
    let tupleBlock = sizer.tree[group]![0]

    // Width: "Hello"(31) + 20 + "World"(27) = 78, Height: max(16, 20, 16) = 20
    #expect(sizer.sizes[tupleBlock]! == .known(Container(height: 20, width: 78, orientation: .horizontal)))
  }

  @Test("Complex nesting spacing")
  func spacingComplexNesting() {
    var sizer = SizeWalker()
    let test = SpacingTestComplexNesting()
    test.walk(with: &sizer)
    let testStruct = sizer.tree[0]![0]
    let group = sizer.tree[testStruct]![0]
    let tupleBlock = sizer.tree[group]![0]
    // This is a complex test - we mainly verify it doesn't crash and produces reasonable results
    if case .known(let container) = sizer.sizes[tupleBlock]! {
      #expect(container.height > 0)
      #expect(container.width > 0)
    }
  }

  @Test("Large size differences")
  func spacingLargeGap() {
    var sizer = SizeWalker()
    let test = SpacingTestLargeGap()
    test.walk(with: &sizer)
    let testStruct = sizer.tree[0]![0]
    let group = sizer.tree[testStruct]![0]
    let tupleBlock = sizer.tree[group]![0]
    // Width: 5 + 100 + 5 = 110, Height: max(5, 100, 5) = 100
    #expect(sizer.sizes[tupleBlock]! == .known(Container(height: 100, width: 110, orientation: .horizontal)))
  }
}

struct RectTestBasic: Block {
  var scale: UInt = 1
  var layer: some Block {
    Rectangle(width: 100, height: 50, color: .red, scale: scale)
  }
}

struct RectTestMultiple: Block {
  var layer: some Block {
    Direction(.horizontal) {
      Rectangle(width: 50, height: 30, color: .red, scale: 1)
      Rectangle(width: 40, height: 60, color: .blue, scale: 1)
      Rectangle(width: 30, height: 40, color: .green, scale: 1)
    }
  }
}

struct RectTestNested: Block {
  var layer: some Block {
    Direction(.vertical) {
      Rectangle(width: 100, height: 20, color: .red, scale: 1)
      Direction(.horizontal) {
        Rectangle(width: 30, height: 30, color: .blue, scale: 1)
        Rectangle(width: 30, height: 30, color: .green, scale: 1)
      }
      Rectangle(width: 100, height: 20, color: .yellow, scale: 1)
    }
  }
}

struct RectTestScaled: Block {
  var layer: some Block {
    Direction(.horizontal) {
      Rectangle(width: 10, height: 10, color: .red, scale: 1)
      Rectangle(width: 10, height: 10, color: .blue, scale: 2)
      Rectangle(width: 10, height: 10, color: .green, scale: 3)
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
  var layer: some Block {
    Direction(.horizontal) {
      Text("Hello").scale(1)
      Rectangle(width: 20, height: 20, color: .red, scale: 1)
      Text("World").scale(1)
    }
  }
}

struct SpacingTestComplexNesting: Block {
  var layer: some Block {
    Direction(.vertical) {
      Text("Top")
      Direction(.horizontal) {
        Rectangle(width: 15, height: 15, color: .red, scale: 1)
        Text("Middle")
        Rectangle(width: 15, height: 15, color: .blue, scale: 1)
      }
      Direction(.horizontal) {
        Rectangle(width: 10, height: 10, color: .green, scale: 1)
        Rectangle(width: 10, height: 10, color: .yellow, scale: 1)
      }
      Text("Bottom")
    }
  }
}

struct SpacingTestLargeGap: Block {
  var layer: some Block {
    Direction(.horizontal) {
      Rectangle(width: 5, height: 5, color: .red, scale: 1)
      Rectangle(width: 100, height: 100, color: .green, scale: 1)
      Rectangle(width: 5, height: 5, color: .blue, scale: 1)
    }
  }
}

// MARK: - Quad Scaling Tests

struct QuadTestScaling: Block {
  var layer: some Block {
    Direction(.horizontal) {
      Rectangle(width: 10, height: 10, color: .red, scale: 1)
      Rectangle(width: 10, height: 10, color: .blue, scale: 2)
      Rectangle(width: 10, height: 10, color: .green, scale: 3)
    }
  }
}

struct QuadCaptureRenderer: Renderer {
  static var capturedQuads: [Quad] = []

  static func drawQuad(_ quad: Quad) {
    capturedQuads.append(quad)
  }

  static func drawText(_ text: RenderableText) {}

  static func reset() {
    capturedQuads.removeAll()
  }
}

@MainActor
@Test("Quad scaling verification")
func quadScaling() {
  var sizer = SizeWalker()
  let test = QuadTestScaling()
  test.walk(with: &sizer)

  var positioner = PositionWalker(sizes: sizer.sizes.convert())
  test.walk(with: &positioner)

  // Reset renderer and capture quads
  QuadCaptureRenderer.reset()
  var renderWalker = RenderWalker(positions: positioner.positions, QuadCaptureRenderer.self, logLevel: .error)
  test.walk(with: &renderWalker)

  // Verify we captured 3 quads
  #expect(QuadCaptureRenderer.capturedQuads.count == 3)

  // Sort by width to get predictable order
  let quads = QuadCaptureRenderer.capturedQuads.sorted { $0.width < $1.width }

  // Verify scaled dimensions are correctly stored in quads
  #expect(quads[0].width == 10)  // 10 * 1
  #expect(quads[0].height == 10)  // 10 * 1
  #expect(quads[1].width == 20)  // 10 * 2
  #expect(quads[1].height == 20)  // 10 * 2
  #expect(quads[2].width == 30)  // 10 * 3
  #expect(quads[2].height == 30)  // 10 * 3
}
