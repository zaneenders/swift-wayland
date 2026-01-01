import Testing

@testable import SwiftWayland
@testable import Wayland

@MainActor
@Test
func fullMockRenderPass() {
  enum TestRenderer: Renderer {
    static var drawnQuads: [Quad] = []
    static var drawnTexts: [Text] = []

    static func drawQuad(_ quad: Quad) {
      drawnQuads.append(quad)
    }

    static func drawText(_ text: Text) {
      drawnTexts.append(text)
    }

    static func reset() {
      drawnQuads.removeAll()
      drawnTexts.removeAll()
    }
  }

  var sizer = SizeWalker()
  let test = Layout()
  test.walk(with: &sizer)

  #expect(!sizer.sizes.isEmpty)

  let testStruct = sizer.tree[0]![0]
  let tupleBlock = sizer.tree[testStruct]![0]
  #expect(sizer.sizes[tupleBlock]! == .known(Container(height: 167, width: 479, orientation: .horizontal)))

  var positioner = PositionWalker(sizes: sizer.sizes.convert())
  test.walk(with: &positioner)
  #expect(positioner.positions.count == sizer.sizes.count)

  TestRenderer.reset()
  var renderWalker = RenderWalker(positions: positioner.positions, TestRenderer.self, logLevel: .error)
  test.walk(with: &renderWalker)

  #expect(!TestRenderer.drawnQuads.isEmpty)
  #expect(!TestRenderer.drawnTexts.isEmpty)

  #expect(TestRenderer.drawnQuads.allSatisfy { $0.dst_p0.0 >= 0 && $0.dst_p0.1 >= 0 })
  #expect(TestRenderer.drawnTexts.allSatisfy { $0.pos.x >= 0 && $0.pos.y >= 0 })

  #expect(TestRenderer.drawnQuads.count == 3)
  #expect(
    TestRenderer.drawnQuads.allSatisfy { quad in
      quad.width == 125 && quad.height == 125
    })

  #expect(
    TestRenderer.drawnTexts.allSatisfy { text in
      !text.text.isEmpty && text.scale == 2
    })
}

@MainActor
@Test func verifyBrightBackgroundColors() {
  enum ColorTestRenderer: Renderer {
    static var drawnTexts: [Text] = []

    static func drawQuad(_ quad: Quad) {
      // Ignore quads for this test
    }

    static func drawText(_ text: Text) {
      drawnTexts.append(text)
    }

    static func reset() {
      drawnTexts.removeAll()
    }
  }

  // Create a simple layout with colored text
  struct ColorTestLayout: Block {
    var layer: some Block {
      Group(.vertical) {
        Word("Red Background").background(.red)
        Word("Bright Yellow Background").background(.yellow)
        Word("Cyan Background").background(.cyan)
      }
    }
  }

  var sizer = SizeWalker()
  let test = ColorTestLayout()
  test.walk(with: &sizer)

  var positioner = PositionWalker(sizes: sizer.sizes.convert())
  test.walk(with: &positioner)

  ColorTestRenderer.reset()
  var renderWalker = RenderWalker(positions: positioner.positions, ColorTestRenderer.self, logLevel: .error)
  test.walk(with: &renderWalker)

  // Verify we captured 3 texts
  #expect(ColorTestRenderer.drawnTexts.count == 3)

  // Check that colored backgrounds are preserved
  #expect(
    ColorTestRenderer.drawnTexts.contains { text in
      text.text == "Red Background" && text.background.r == 1.0 && text.background.g == 0.0 && text.background.b == 0.0
    })

  #expect(
    ColorTestRenderer.drawnTexts.contains { text in
      text.text == "Bright Yellow Background" && text.background.r == 1.0 && text.background.g == 1.0
        && text.background.b == 0.0
    })

  #expect(
    ColorTestRenderer.drawnTexts.contains { text in
      text.text == "Cyan Background" && text.background.r == 0.0 && text.background.g == 1.0 && text.background.b == 1.0
    })
}

@Test func cloudFlare() async {
  let ips = await getIps()
  #expect(ips.count > 0)
  #expect(ips.allSatisfy { $0.contains(".") })
}

@Test func hashing() async {
  let chromaHash = hash("Chroma")
  #expect(chromaHash == 4_247_990_530_641_679_754)

  let chromaHash2 = hash("Chroma")
  #expect(chromaHash == chromaHash2)

  let rehash = hash(chromaHash)
  #expect(chromaHash != rehash)
}
