import Fixtures
import Testing

@testable import ShapeTree
@testable import SwiftWayland
@testable import Wayland

@MainActor
@Suite(.serialized)
struct CaptureRendererTests {

  @Test
  func fullMockRenderPass() {
    TestUtils.CaptureRenderer.reset()
    let test = Layout(scale: 1)
    let result = TestUtils.renderBlock(
      test, height: Wayland.windowHeight, width: Wayland.windowWidth, with: TestUtils.CaptureRenderer.self)

    #expect(!result.sizes.sizes.isEmpty, "Should have calculated sizes")

    guard let tupleBlock = TestUtils.TreeNavigator.findFirstTupleBlock(in: result.attributes),
      let size = result.sizes.sizes[tupleBlock]
    else {
      Issue.record("Failed to find tuple block or get size")
      return
    }

    #expect(
      size == Size.known(Container(height: Wayland.windowHeight, width: Wayland.windowWidth, orientation: .vertical)),
      "Layout should have expected dimensions")

    #expect(
      result.positions.positions.count == result.sizes.sizes.count,
      "Should have position for every sized element")

    #expect(!TestUtils.CaptureRenderer.capturedQuads.isEmpty, "Should have drawn quads")

    TestUtils.CaptureRenderer.capturedQuads.forEach { TestUtils.Assert.quadHasValidCoordinates($0) }

    #expect(TestUtils.CaptureRenderer.capturedQuads.count >= 3, "Should draw at least 3 quads")

    #expect(
      TestUtils.CaptureRenderer.capturedQuads.allSatisfy { $0.width == 25 && $0.height == 25 },
      "All quads should be 25x25")
  }

  @Test
  func verifyBrightBackgroundColors() {
    TestUtils.CaptureRenderer.reset()

    let test = ColorTestLayout()
    _ = TestUtils.renderBlock(
      test, height: Wayland.windowHeight, width: Wayland.windowWidth, with: TestUtils.CaptureRenderer.self)

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
