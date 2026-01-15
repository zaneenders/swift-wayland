import Foundation
import Testing

@testable import Wayland

let width: UInt = 600
let height: UInt = 400

/// Test utilities to reduce duplication and improve test reliability
@MainActor
enum TestUtils {

  /// Common renderer for capturing quads during tests
  enum QuadCaptureRenderer: Renderer {
    static var capturedQuads: [RenderableQuad] = []

    static func drawQuad(_ quad: RenderableQuad) {
      capturedQuads.append(quad)
    }

    static func drawText(_ text: RenderableText) {}

    nonisolated static func reset() {
      Task { @MainActor in
        capturedQuads.removeAll()
      }
    }
  }

  /// Common renderer for capturing text during tests
  enum TextCaptureRenderer: Renderer {
    static var capturedTexts: [RenderableText] = []

    static func drawQuad(_ quad: RenderableQuad) {}

    static func drawText(_ text: RenderableText) {
      capturedTexts.append(text)
    }

    nonisolated static func reset() {
      Task { @MainActor in
        capturedTexts.removeAll()
      }
    }
  }

  /// Walk a block through all standard walkers
  static func walkBlock(_ block: any Block, height: UInt, width: UInt) -> (
    attributes: AttributesWalker, sizes: SizeWalker, positions: PositionWalker, grower: GrowWalker
  ) {
    var attributesWalker = AttributesWalker()
    block.walk(with: &attributesWalker)

    var sizeWalker = SizeWalker(attributes: attributesWalker.attributes)
    block.walk(with: &sizeWalker)

    let containers = sizeWalker.sizes.convert()
    var grower = GrowWalker(sizes: containers, attributes: attributesWalker.attributes)
    block.walk(with: &grower)

    var positionWalker = PositionWalker(sizes: containers, attributes: attributesWalker.attributes)
    block.walk(with: &positionWalker)

    return (attributes: attributesWalker, sizes: sizeWalker, positions: positionWalker, grower: grower)
  }

  /// Render a block with specified renderer
  static func renderBlock(_ block: any Block, height: UInt, width: UInt, with renderer: any Renderer.Type) -> (
    attributes: AttributesWalker, sizes: SizeWalker, positions: PositionWalker, grower: GrowWalker
  ) {
    let result = walkBlock(block, height: height, width: width)

    // Reset renderer if it has a reset method
    if let resettableRenderer = renderer as? any TestResettableRenderer.Type {
      resettableRenderer.reset()
    }

    // Convert Size to Container for RenderWalker
    var containers: [Hash: Container] = [:]
    for (id, size) in result.sizes.sizes {
      if case .known(let container) = size {
        containers[id] = container
      }
    }

    var renderWalker = RenderWalker(
      positions: result.positions.positions,
      sizes: containers,
      renderer,
      logLevel: .error
    )
    block.walk(with: &renderWalker)

    return result
  }

  /// Navigate through tree structure to find specific elements
  @MainActor
  enum TreeNavigator {
    static func findFirstTupleBlock(in attributes: AttributesWalker) -> Hash? {
      return attributes.tree[0]?.first
    }

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

  /// Common test data generators
  enum TestData {
    static let basicColors: [Color] = [.red, .green, .blue, .yellow, .cyan, .magenta]
    static let testTexts = ["Hello", "World", "Test", "Swift", "Wayland"]
    static let commonScales: [UInt] = [1, 2, 3, 5, 10]

    static func randomColor() -> Color {
      basicColors.randomElement() ?? .black
    }

    static func randomText() -> String {
      testTexts.randomElement() ?? "Test"
    }

    static func randomScale() -> UInt {
      commonScales.randomElement() ?? 1
    }
  }

  /// Assertion helpers
  enum Assert {
    static func validPosition(_ position: (x: Int, y: Int)) {
      #expect(position.x >= 0 && position.y >= 0, "Position should be non-negative")
    }

    static func positiveSize(_ size: Size) {
      if case .known(let container) = size {
        #expect(container.width > 0 && container.height > 0, "Size should be positive")
      }
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

/// Protocol for renderers that can be reset
protocol TestResettableRenderer {
  static func reset()
}

// Make our renderers conform to the reset protocol
extension TestUtils.QuadCaptureRenderer: TestResettableRenderer {}
extension TestUtils.TextCaptureRenderer: TestResettableRenderer {}
