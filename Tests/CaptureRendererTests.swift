import Fixtures
import Testing

@testable import ShapeTree
@testable import SwiftWayland
@testable import Wayland

@MainActor
@Suite(.serialized)
struct CaptureRendererTests {
  init() {
    TestUtils.CaptureRenderer.reset()
  }

  @Test func textRenderingWithScale() {
    let block = TextTestScaling()

    var attributesWalker = AttributesWalker()
    block.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    block.walk(with: &sizer)

    var positioner = PositionWalker(sizes: sizer.sizes.convert(), attributes: attributesWalker.attributes)
    block.walk(with: &positioner)

    var renderWalker = RenderWalker(
      settings: Wayland.fontSettings,
      positions: positioner.positions, sizes: sizer.sizes.convert(), TestUtils.CaptureRenderer.self, logLevel: .error)
    block.walk(with: &renderWalker)

    #expect(TestUtils.CaptureRenderer.capturedTexts.count == 3)

    let texts = TestUtils.CaptureRenderer.capturedTexts.sorted { $0.scale < $1.scale }

    #expect(texts[0].scale == 1)
    #expect(texts[0].text == "Small")
    #expect(texts[1].scale == 1)
    #expect(texts[1].text == "Medium")
    #expect(texts[2].scale == 1)
    #expect(texts[2].text == "Large")

    #expect(texts[0].foreground == Color.red.rgb())
    #expect(texts[1].foreground == Color.green.rgb())
    #expect(texts[2].foreground == Color.blue.rgb())
  }

  @Test
  func quadScaling() {
    let test = QuadTestScaling()
    var attributesWalker = AttributesWalker()
    test.walk(with: &attributesWalker)
    var sizer = SizeWalker(settings: Wayland.fontSettings, attributes: attributesWalker.attributes)
    test.walk(with: &sizer)

    var positioner = PositionWalker(sizes: sizer.sizes.convert(), attributes: attributesWalker.attributes)
    test.walk(with: &positioner)

    var renderWalker = RenderWalker(
      settings: Wayland.fontSettings,
      positions: positioner.positions, sizes: sizer.sizes.convert(),
      TestUtils.CaptureRenderer.self, logLevel: .error)
    test.walk(with: &renderWalker)

    let nonZeroQuads = TestUtils.CaptureRenderer.capturedQuads.filter {
      $0.width > 0 && $0.height > 0
    }

    #expect(nonZeroQuads.count == 3)

    let quads = nonZeroQuads.sorted { $0.width < $1.width }

    #expect(quads[0].width == 10)
    #expect(quads[0].height == 10)
    #expect(quads[1].width == 10)
    #expect(quads[1].height == 10)
    #expect(quads[2].width == 10)
    #expect(quads[2].height == 10)
  }

  @Test
  func fullMockRenderPass() {
    let test = Layout(scale: 1)
    let layout = calculateLayout(test)
    _ = TestUtils.render(
      test, layout: layout, with: TestUtils.CaptureRenderer.self)

    guard let tupleBlock = layout.tree[0]?.first,
      let size = layout.sizes[tupleBlock]
    else {
      Issue.record("Failed to find tuple block or get size")
      return
    }

    #expect(
      size == Container(height: Wayland.windowHeight, width: Wayland.windowWidth, orientation: .vertical),
      "Layout should have expected dimensions")

    #expect(
      layout.positions.count == layout.sizes.count,
      "Should have position for every sized element")

    #expect(!TestUtils.CaptureRenderer.capturedQuads.isEmpty, "Should have drawn quads")

    TestUtils.CaptureRenderer.capturedQuads.forEach { TestUtils.Assert.quadHasValidCoordinates($0) }

    #expect(TestUtils.CaptureRenderer.capturedQuads.count == 6, "Should draw at least 3 quads")
    #expect(
      TestUtils.CaptureRenderer.capturedQuads.allSatisfy { $0.width == 25 && $0.height == 25 },
      "All quads should be 25x25")
  }

  @Test
  func verifyBrightBackgroundColors() {

    let test = ColorTestLayout()
    let layout = calculateLayout(test)
    _ = TestUtils.render(
      test, layout: layout, with: TestUtils.CaptureRenderer.self)

    #expect(
      TestUtils.CaptureRenderer.capturedTexts.count >= 3,
      "Should capture at least 3 texts with backgrounds")

    let expectedColors = [
      ("Red Background", RGB(r: 1.0, g: 0.0, b: 0.0, a: 1.0)),
      ("Bright Yellow Background", RGB(r: 1.0, g: 1.0, b: 0.0, a: 1.0)),
      ("Cyan Background", RGB(r: 0.0, g: 1.0, b: 1.0, a: 1.0)),
    ]

    for (text, expectedColor) in expectedColors {
      #expect(
        TestUtils.CaptureRenderer.capturedTexts.contains { captured in
          captured.text == text && captured.background == expectedColor
        }, "Should preserve color for '\(text)'")
    }
  }
}
