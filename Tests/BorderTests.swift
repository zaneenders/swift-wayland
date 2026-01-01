import Testing

@testable import Wayland

@MainActor
@Suite
struct BorderTests {

  @Test("Rectangle border property initialization")
  func rectBorderProperties() {
    let rectWithoutBorder = Rectangle(width: 10, height: 15, color: .blue, scale: 2)
    #expect(rectWithoutBorder.borderWidth == 0)
    #expect(rectWithoutBorder.borderColor == nil)
    #expect(rectWithoutBorder.width == 10)
    #expect(rectWithoutBorder.height == 15)
    #expect(rectWithoutBorder.color == .blue)
    #expect(rectWithoutBorder.scale == 2)

    let rectWithBorder = Rectangle(
      width: 20,
      height: 25,
      color: .green,
      scale: 3,
      borderWidth: 4,
      borderColor: .red
    )
    #expect(rectWithBorder.borderWidth == 4)
    #expect(rectWithBorder.borderColor == .red)
    #expect(rectWithBorder.width == 20)
    #expect(rectWithBorder.height == 25)
    #expect(rectWithBorder.color == .green)
    #expect(rectWithBorder.scale == 3)

    // Test rectangle with zero border width but specified color
    let rectZeroBorder = Rectangle(
      width: 15,
      height: 10,
      color: .yellow,
      scale: 1,
      borderWidth: 0,
      borderColor: .purple
    )
    #expect(rectZeroBorder.borderWidth == 0)
    #expect(rectZeroBorder.borderColor == .purple)
  }

  @Test("Rectangle border defaults")
  func rectBorderDefaults() {
    // Test that default constructor creates no border
    let rectDefault = Rectangle(width: 5, height: 8, color: .cyan, scale: 2)
    #expect(rectDefault.borderWidth == 0)
    #expect(rectDefault.borderColor == nil)
  }

  @Test("Border sizing doesn't affect rectangle size")
  func borderSizingIndependence() {
    var sizer = SizeWalker()
    let test = BorderSizingTest()
    test.walk(with: &sizer)

    let testStruct = sizer.tree[0]![0]
    let group = sizer.tree[testStruct]![0]
    let tupleBlock = sizer.tree[group]![0]

    if case .known(let container) = sizer.sizes[tupleBlock]! {
      #expect(container.width == 80)
      #expect(container.height == 30)
      #expect(container.orientation == .horizontal)
    }
  }

  @Test("Border rendering captures quads")
  func borderRenderingCapture() {
    var sizer = SizeWalker()
    let test = MultipleBorderColorsTest()
    test.walk(with: &sizer)

    var positioner = PositionWalker(sizes: sizer.sizes.convert())
    test.walk(with: &positioner)

    BorderCaptureRenderer.reset()
    var renderWalker = RenderWalker(positions: positioner.positions, BorderCaptureRenderer.self, logLevel: .error)
    test.walk(with: &renderWalker)

    #expect(BorderCaptureRenderer.capturedQuads.count == 3)

    let redBorderQuads = BorderCaptureRenderer.capturedQuads.filter { $0.borderColor == .red }
    let blueBorderQuads = BorderCaptureRenderer.capturedQuads.filter { $0.borderColor == .blue }
    let yellowNoBorderQuads = BorderCaptureRenderer.capturedQuads.filter { $0.color == .yellow && $0.borderWidth == 0 }

    #expect(redBorderQuads.count == 1)  // Rectangle with red border
    #expect(blueBorderQuads.count == 1)  // Rectangle with blue border
    #expect(yellowNoBorderQuads.count == 1)  // No border
  }

  @Test("Border positioning verification")
  func borderPositioning() {
    var sizer = SizeWalker()
    let test = BorderPositionTest()
    test.walk(with: &sizer)

    var positioner = PositionWalker(sizes: sizer.sizes.convert())
    test.walk(with: &positioner)

    BorderCaptureRenderer.reset()
    var renderWalker = RenderWalker(positions: positioner.positions, BorderCaptureRenderer.self, logLevel: .error)
    test.walk(with: &renderWalker)

    #expect(BorderCaptureRenderer.capturedQuads.count == 1)

    let mainRect = BorderCaptureRenderer.capturedQuads.first!
    #expect(mainRect.width == 40)
    #expect(mainRect.height == 30)
    #expect(mainRect.color == .green)
    #expect(mainRect.borderColor == .red)
    #expect(mainRect.borderWidth == 3.0)
  }

  @Test("No border rectangles don't generate extra quads")
  func noBorderExtraQuads() {
    var sizer = SizeWalker()
    let test = NoBorderTest()
    test.walk(with: &sizer)

    var positioner = PositionWalker(sizes: sizer.sizes.convert())
    test.walk(with: &positioner)

    BorderCaptureRenderer.reset()
    var renderWalker = RenderWalker(positions: positioner.positions, BorderCaptureRenderer.self, logLevel: .error)
    test.walk(with: &renderWalker)

    #expect(BorderCaptureRenderer.capturedQuads.count == 2)

    let blueQuads = BorderCaptureRenderer.capturedQuads.filter { $0.color == .blue }
    let yellowQuads = BorderCaptureRenderer.capturedQuads.filter { $0.color == .yellow }

    #expect(blueQuads.count == 1)
    #expect(yellowQuads.count == 1)
  }

  @Test("Zero border width doesn't generate border quads")
  func zeroBorderWidthTest() {
    var sizer = SizeWalker()
    let test = ZeroBorderWidthTest()
    test.walk(with: &sizer)

    var positioner = PositionWalker(sizes: sizer.sizes.convert())
    test.walk(with: &positioner)

    BorderCaptureRenderer.reset()
    var renderWalker = RenderWalker(positions: positioner.positions, BorderCaptureRenderer.self, logLevel: .error)
    test.walk(with: &renderWalker)

    #expect(BorderCaptureRenderer.capturedQuads.count == 1)
    #expect(BorderCaptureRenderer.capturedQuads.first!.color == .purple)
  }

  @Test("Multiple border colors in layout")
  func multipleBorderColors() {
    var sizer = SizeWalker()
    let test = MultipleBorderColorsTest()
    test.walk(with: &sizer)

    var positioner = PositionWalker(sizes: sizer.sizes.convert())
    test.walk(with: &positioner)

    BorderCaptureRenderer.reset()
    var renderWalker = RenderWalker(positions: positioner.positions, BorderCaptureRenderer.self, logLevel: .error)
    test.walk(with: &renderWalker)

    #expect(BorderCaptureRenderer.capturedQuads.count == 3)

    let cyanQuads = BorderCaptureRenderer.capturedQuads.filter { $0.color == .cyan && $0.borderColor == .red }
    let magentaQuads = BorderCaptureRenderer.capturedQuads.filter { $0.color == .magenta && $0.borderColor == .blue }
    let yellowQuads = BorderCaptureRenderer.capturedQuads.filter { $0.color == .yellow && $0.borderWidth == 0 }

    #expect(cyanQuads.count == 1)
    #expect(cyanQuads.first!.borderWidth == 2.0)
    #expect(magentaQuads.count == 1)
    #expect(magentaQuads.first!.borderWidth == 4.0)
    #expect(yellowQuads.count == 1)
  }
}

struct BorderSizingTest: Block {
  var layer: some Block {
    Group(.horizontal) {
      Rectangle(width: 20, height: 15, color: .blue, scale: 2)
      Rectangle(width: 20, height: 15, color: .green, scale: 2, borderWidth: 10, borderColor: .red)
    }
  }
}

struct BorderPositionTest: Block {
  var layer: some Block {
    Rectangle(width: 20, height: 15, color: .green, scale: 2, borderWidth: 3, borderColor: .red)
  }
}

struct NoBorderTest: Block {
  var layer: some Block {
    Group(.horizontal) {
      Rectangle(width: 10, height: 8, color: .blue, scale: 1)
      Rectangle(width: 12, height: 10, color: .yellow, scale: 2)
    }
  }
}

struct ZeroBorderWidthTest: Block {
  var layer: some Block {
    Rectangle(width: 25, height: 20, color: .purple, scale: 1, borderWidth: 0, borderColor: .orange)
  }
}

struct MultipleBorderColorsTest: Block {
  var layer: some Block {
    Group(.horizontal) {
      Rectangle(width: 15, height: 10, color: .cyan, scale: 2, borderWidth: 2, borderColor: .red)
      Rectangle(width: 15, height: 10, color: .magenta, scale: 2, borderWidth: 4, borderColor: .blue)
      Rectangle(width: 15, height: 10, color: .yellow, scale: 2)  // No border
    }
  }
}

enum BorderCaptureRenderer: Renderer {
  static var capturedQuads: [Quad] = []

  static func drawQuad(_ quad: Quad) {
    capturedQuads.append(quad)
  }

  static func drawText(_ text: Text) {
  }

  static func drawBorder(around rect: Rect, at pos: (x: UInt, y: UInt), width: UInt, color: Color) {
    // No-op - borders are now handled in the shader via the main quad
  }



  static func reset() {
    capturedQuads.removeAll()
  }
}
