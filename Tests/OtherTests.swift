import Testing

@testable import ShapeTree
@testable import SwiftWayland
@testable import Wayland

@MainActor
@Suite("Integration Tests")
struct IntegrationTests {

  @Test("Full mock render pass")
  func fullMockRenderPass() {
    let test = Layout(scale: 1)
    let result = TestUtils.renderBlock(test, height: height, width: width, with: TestUtils.QuadCaptureRenderer.self)

    #expect(!result.sizes.sizes.isEmpty, "Should have calculated sizes")

    guard let tupleBlock = TestUtils.TreeNavigator.findFirstTupleBlock(in: result.attributes),
      let size = result.sizes.sizes[tupleBlock]
    else {
      Issue.record("Failed to find tuple block or get size")
      return
    }

    #expect(
      size == Size.known(Container(height: 46, width: 137, orientation: .vertical)),
      "Layout should have expected dimensions")

    #expect(
      result.positions.positions.count == result.sizes.sizes.count,
      "Should have position for every sized element")

    #expect(!TestUtils.QuadCaptureRenderer.capturedQuads.isEmpty, "Should have drawn quads")

    TestUtils.QuadCaptureRenderer.capturedQuads.forEach { TestUtils.Assert.quadHasValidCoordinates($0) }

    #expect(TestUtils.QuadCaptureRenderer.capturedQuads.count >= 3, "Should draw at least 3 quads")

    #expect(
      TestUtils.QuadCaptureRenderer.capturedQuads.allSatisfy { $0.width == 25 && $0.height == 25 },
      "All quads should be 25x25")
  }
}

@Suite("Color and Utility Tests")
@MainActor
struct ColorAndUtilityTests {

  @Test("Bright background colors preservation")
  func verifyBrightBackgroundColors() {
    struct ColorTestLayout: Block {
      var layer: some Block {
        Direction(.vertical) {
          Text("Red Background").background(.red)
          Text("Bright Yellow Background").background(.yellow)
          Text("Cyan Background").background(.cyan)
        }
      }
    }

    let test = ColorTestLayout()
    _ = TestUtils.renderBlock(test, height: height, width: width, with: TestUtils.TextCaptureRenderer.self)

    #expect(
      TestUtils.TextCaptureRenderer.capturedTexts.count >= 3,
      "Should capture at least 3 texts with backgrounds")

    let expectedColors = [
      ("Red Background", Color(r: 1.0, g: 0.0, b: 0.0, a: 1.0)),
      ("Bright Yellow Background", Color(r: 1.0, g: 1.0, b: 0.0, a: 1.0)),
      ("Cyan Background", Color(r: 0.0, g: 1.0, b: 1.0, a: 1.0)),
    ]

    for (text, expectedColor) in expectedColors {
      #expect(
        TestUtils.TextCaptureRenderer.capturedTexts.contains { captured in
          captured.text == text && captured.background == expectedColor
        }, "Should preserve color for '\(text)'")
    }
  }
}

@Suite("Network and Utility Tests")
struct NetworkAndUtilityTests {

  @Test("CloudFlare IP lookup")
  func cloudFlare() async {
    let ips = await getIps()
    #expect(ips.count > 0, "Should return at least one IP address")
    #expect(ips.allSatisfy { $0.contains(".") }, "All IPs should contain dots")
  }

  @Test("Hash function consistency")
  func hashing() async {
    let chromaHash = hash("Chroma")
    #expect(chromaHash == 4_247_990_530_641_679_754, "Hash should match expected value")

    let chromaHash2 = hash("Chroma")
    #expect(chromaHash == chromaHash2, "Same input should produce same hash")

    let rehash = hash(chromaHash)
    #expect(chromaHash != rehash, "Hashing a hash should produce different result")

    // Test edge cases
    #expect(hash("") != hash(" "), "Empty string should hash differently from space")
    #expect(hash("a") != hash("A"), "Case sensitivity should be preserved")
  }
}
