import Foundation
import Testing

@testable import ShapeTree
@testable import Wayland

@MainActor
enum TestUtils {

  enum CaptureRenderer: Renderer {
    static var capturedTexts: [RenderableText] = []
    static var capturedQuads: [RenderableQuad] = []

    static func drawQuad(_ quad: RenderableQuad) {
      capturedQuads.append(quad)
    }

    static func drawText(_ text: RenderableText) {
      capturedTexts.append(text)
    }

    nonisolated static func reset() {
      Task { @MainActor in
        capturedTexts.removeAll()
      }
    }
  }

  static func render(_ block: some Block, layout: Layout, with renderer: any Renderer.Type)
    -> RenderWalker
  {
    var renderWalker = RenderWalker(
      settings: Wayland.fontSettings,
      positions: layout.positions,
      sizes: layout.sizes,
      renderer,
      logLevel: .error
    )
    block.walk(with: &renderWalker)
    return renderWalker
  }

  @MainActor
  enum TreeNavigator {

    static func findChildren(in attributes: AttributesWalker, parentId: Hash) -> [Hash]? {
      return attributes.tree[parentId]
    }

    static func findNestedChild(in attributes: AttributesWalker, path: [Int]) -> Hash? {
      var currentId: Hash = 0
      for index in path {
        guard let children = attributes.tree[currentId],
          index < children.count
        else {
          return nil
        }
        currentId = children[index]
      }
      return currentId
    }
  }

  enum TestData {
    static let basicColors: [Color] = [.red, .green, .blue, .yellow, .cyan, .magenta]
    static let testTexts = ["Hello", "World", "Test", "Swift", "Wayland"]
    static let commonScales: [UInt] = [1, 2, 3, 5, 10]

    static func randomColor() -> RGB {
      (basicColors.randomElement() ?? Color.black).rgb()
    }

    static func randomText() -> String {
      testTexts.randomElement() ?? "Test"
    }

    static func randomScale() -> UInt {
      commonScales.randomElement() ?? 1
    }
  }

  enum Assert {
    static func validPosition(_ position: (x: Int, y: Int)) {
      #expect(position.x >= 0 && position.y >= 0, "Position should be non-negative")
    }

    static func quadHasValidCoordinates(_ quad: RenderableQuad) {
      #expect(quad.dst_p0.0 >= 0 && quad.dst_p0.1 >= 0, "Quad position should be non-negative")
      #expect(quad.width > 0 && quad.height > 0, "Quad dimensions should be positive")
    }

    static func textHasValidProperties(_ text: RenderableText) {
      #expect(!text.text.isEmpty, "Text should not be empty")
      #expect(text.scale > 0, "Text scale should be positive")
      #expect(text.pos.x >= 0 && text.pos.y >= 0, "Text position should be non-negative")
    }
  }
}

protocol TestResettableRenderer {
  static func reset()
}
extension TestUtils.CaptureRenderer: TestResettableRenderer {}
