import Foundation
import Testing

@testable import ShapeTree
@testable import Wayland

@MainActor
/// Used to visualize and debug parsed information from the tree
struct VisualizeWalker: Walker {
  var currentId: Hash = 0
  var parentId: Hash = 0
  let layout: Layout
  var nodeInfo: [Hash: String] = [:]
  func display() -> String {
    var result: [String] = []
    result.append("=== Tree Layout Visualization ===")
    result.append("")

    result.append("Tree Structure:")
    displayTree(rootId: 0, level: 0, result: &result)
    result.append("")

    result.append("Node Details:")
    let sortedIds = layout.tree.keys.sorted()
    for id in sortedIds {
      displayNodeInfo(id: id, result: &result)
      result.append("")
    }

    return result.joined(separator: "\n")
  }

  private func displayTree(rootId: Hash, level: Int, result: inout [String]) {
    let indent = String(repeating: "  ", count: level)
    let nodeType = getNodeType(id: rootId)
    result.append("\(indent)Node \(rootId): \(nodeType)")

    if let children = layout.tree[rootId], !children.isEmpty {
      for childId in children {
        displayTree(rootId: childId, level: level + 1, result: &result)
      }
    }
  }

  private func getNodeType(id: Hash) -> String {
    if let info = nodeInfo[id] {
      return info
    }

    guard let attributes = layout.attributes[id] else { return "Unknown" }

    if let foreground = attributes.foreground, let scale = attributes.scale {
      return "Text (scale: \(scale), color: \(foregroundColor(foreground)))"
    } else if attributes.background != nil {
      return "Container (bg: \(foregroundColor(attributes.background!)))"
    } else {
      return "Container"
    }
  }

  private func foregroundColor(_ color: Color) -> String {
    let rgb = color.rgb()
    return "rgb(\(Int(rgb.r * 255)),\(Int(rgb.g * 255)),\(Int(rgb.b * 255)))"
  }

  private func displayNodeInfo(id: Hash, result: inout [String]) {
    result.append("Node \(id):")

    if let pos = layout.positions[id] {
      result.append("  Position: (\(pos.x), \(pos.y))")
    }

    if let container = layout.sizes[id] {
      result.append("  Size: \(container.width) x \(container.height)")
      result.append("  Orientation: \(container.orientation)")
    }

    if let attrs = layout.attributes[id] {
      result.append("  Attributes:")
      result.append("    Width: \(attrs.width)")
      result.append("    Height: \(attrs.height)")

      if let fg = attrs.foreground {
        result.append("    Foreground: \(foregroundColor(fg))")
      }

      if let bg = attrs.background {
        result.append("    Background: \(foregroundColor(bg))")
      }

      if let scale = attrs.scale {
        result.append("    Scale: \(scale)")
      }

      if let padding = attrs.padding {
        var paddingStr = "    Padding: "
        if let t = padding.top { paddingStr += "top:\(t) " }
        if let r = padding.right { paddingStr += "right:\(r) " }
        if let b = padding.bottom { paddingStr += "bottom:\(b) " }
        if let l = padding.left { paddingStr += "left:\(l) " }
        result.append(paddingStr)
      }
    }

    if let children = layout.tree[id], !children.isEmpty {
      result.append("  Children: \(children.map(String.init).joined(separator: ", "))")
    }
  }

  private mutating func captureBlockInfo(_ block: some Block) {
    var info = ""
    if let text = block as? Text {
      info = "Text: \"\(text.label)\""
    } else if let attributedBlock = block as? AttributedBlock<Text> {
      info = "Text: \"\(attributedBlock.layer.label)\""
    } else if let directionGroup = block as? any DirectionGroup {
      info = "Direction: \(directionGroup.orientation)"
    } else if block is Rect {
      info = "Rect"
    } else if let hasAttribs = block as? any HasAttributes {
      info = "Attributed: \(type(of: hasAttribs.layer))"
    } else {
      info = "\(type(of: block))"
    }
    nodeInfo[currentId] = info
  }

  mutating func before(_ block: some Block) {
    captureBlockInfo(block)
  }
  mutating func after(_ block: some Block) {}
  mutating func before(child block: some Block) {
    captureBlockInfo(block)
  }
  mutating func after(child block: some Block) {}
}

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
        capturedQuads.removeAll()
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
