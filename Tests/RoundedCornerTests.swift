import Testing

@testable import Wayland

@MainActor
@Suite
struct RoundedCornerTests {

  @Test("Rectangle corner radius property initialization")
  func rectCornerRadiusProperties() {
    let rectNoRadius = Rectangle(width: 10, height: 15, color: .blue, scale: 2)
    #expect(rectNoRadius.cornerRadius == 0)
    #expect(rectNoRadius.width == 10)
    #expect(rectNoRadius.height == 15)
    #expect(rectNoRadius.color == .blue)
    #expect(rectNoRadius.scale == 2)

    let rectWithRadius = Rectangle(
      width: 20,
      height: 25,
      color: .green,
      scale: 3,
      borderWidth: 4,
      borderColor: .red,
      cornerRadius: 8
    )
    #expect(rectWithRadius.cornerRadius == 8)
    #expect(rectWithRadius.borderWidth == 4)
    #expect(rectWithRadius.borderColor == .red)
    #expect(rectWithRadius.width == 20)
    #expect(rectWithRadius.height == 25)
    #expect(rectWithRadius.color == .green)
    #expect(rectWithRadius.scale == 3)

    // Test rectangle with max corner radius
    let rectMaxRadius = Rectangle(
      width: 30,
      height: 40,
      color: .purple,
      scale: 1,
      borderWidth: 2,
      borderColor: .yellow,
      cornerRadius: 20
    )
    #expect(rectMaxRadius.cornerRadius == 20)
    #expect(rectMaxRadius.width == 30)
    #expect(rectMaxRadius.height == 40)
  }

  @Test("Rectangle corner radius defaults")
  func rectCornerRadiusDefaults() {
    // Test that default constructor creates no corner radius
    let rectDefault = Rectangle(width: 5, height: 8, color: .cyan, scale: 2)
    #expect(rectDefault.cornerRadius == 0)
    #expect(rectDefault.borderWidth == 0)
    #expect(rectDefault.borderColor == Color(r: 0, g: 0, b: 0, a: 0))
  }

  @Test("Quad corner radius propagation")
  func quadCornerRadiusPropagation() {
    let rect = Rectangle(
      width: 15,
      height: 20,
      color: .magenta,
      scale: 2,
      borderWidth: 3,
      borderColor: .orange,
      cornerRadius: 6
    )

    let quad = Quad(pos: (10, 15), rect)

    #expect(quad.cornerRadius == 6.0)
    #expect(quad.borderWidth == 3.0)
    #expect(quad.borderColor == .orange)
    #expect(quad.color == .magenta)
  }

  @Test("Multiple corner radius values in layout")
  func multipleCornerRadiusValues() {
    var sizer = SizeWalker()
    let test = MultipleCornerRadiusTest()
    test.walk(with: &sizer)

    var positioner = PositionWalker(sizes: sizer.sizes.convert())
    test.walk(with: &positioner)

    BorderCaptureRenderer.reset()
    var renderWalker = RenderWalker(positions: positioner.positions, BorderCaptureRenderer.self, logLevel: .error)
    test.walk(with: &renderWalker)

    #expect(BorderCaptureRenderer.capturedQuads.count == 4)

    let zeroRadiusQuads = BorderCaptureRenderer.capturedQuads.filter { $0.cornerRadius == 0.0 }
    let smallRadiusQuads = BorderCaptureRenderer.capturedQuads.filter { $0.cornerRadius == 5.0 }
    let mediumRadiusQuads = BorderCaptureRenderer.capturedQuads.filter { $0.cornerRadius == 10.0 }
    let largeRadiusQuads = BorderCaptureRenderer.capturedQuads.filter { $0.cornerRadius == 15.0 }

    #expect(zeroRadiusQuads.count == 1)  // Sharp corners
    #expect(smallRadiusQuads.count == 1)  // Small rounded corners
    #expect(mediumRadiusQuads.count == 1)  // Medium rounded corners
    #expect(largeRadiusQuads.count == 1)  // Large rounded corners
  }

  @Test("Rounded corners with different border widths")
  func roundedCornersWithBorders() {
    var sizer = SizeWalker()
    let test = RoundedCornerBorderTest()
    test.walk(with: &sizer)

    var positioner = PositionWalker(sizes: sizer.sizes.convert())
    test.walk(with: &positioner)

    BorderCaptureRenderer.reset()
    var renderWalker = RenderWalker(positions: positioner.positions, BorderCaptureRenderer.self, logLevel: .error)
    test.walk(with: &renderWalker)

    #expect(BorderCaptureRenderer.capturedQuads.count == 3)

    let thinBorderQuads = BorderCaptureRenderer.capturedQuads.filter { $0.borderWidth == 2.0 && $0.cornerRadius == 8.0 }
    let mediumBorderQuads = BorderCaptureRenderer.capturedQuads.filter {
      $0.borderWidth == 5.0 && $0.cornerRadius == 12.0
    }
    let thickBorderQuads = BorderCaptureRenderer.capturedQuads.filter {
      $0.borderWidth == 8.0 && $0.cornerRadius == 15.0
    }

    #expect(thinBorderQuads.count == 1)
    #expect(mediumBorderQuads.count == 1)
    #expect(thickBorderQuads.count == 1)

    #expect(thinBorderQuads.first!.borderColor == .red)
    #expect(mediumBorderQuads.first!.borderColor == .green)
    #expect(thickBorderQuads.first!.borderColor == .blue)
  }
}

// Test helper structures
struct MultipleCornerRadiusTest: Block {
  var layer: some Block {
    Direction(.horizontal) {
      Rect(width: 20, height: 15, color: .cyan, scale: 2, borderWidth: 2, borderColor: .red, cornerRadius: 0)
      Rect(width: 20, height: 15, color: .magenta, scale: 2, borderWidth: 2, borderColor: .red, cornerRadius: 5)
      Rect(width: 20, height: 15, color: .yellow, scale: 2, borderWidth: 2, borderColor: .red, cornerRadius: 10)
      Rect(width: 20, height: 15, color: .green, scale: 2, borderWidth: 2, borderColor: .red, cornerRadius: 15)
    }
  }
}

struct RoundedCornerBorderTest: Block {
  var layer: some Block {
    Direction(.horizontal) {
      Rect(width: 25, height: 20, color: .white, scale: 2, borderWidth: 2, borderColor: .red, cornerRadius: 8)
      Rect(width: 25, height: 20, color: .cyan, scale: 2, borderWidth: 5, borderColor: .green, cornerRadius: 12)
      Rect(width: 25, height: 20, color: .gray, scale: 2, borderWidth: 8, borderColor: .blue, cornerRadius: 15)
    }
  }
}
