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
    result.append("Tree Structure:")
    displayTree(rootId: 0, level: 0, result: &result)
    result.append("")

    result.append("Node Details:")
    for id in nodeInfo.keys.sorted() {
      displayNodeInfo(id: id, result: &result)
      result.append("")
    }

    return result.joined(separator: "\n")
  }

  private func displayTree(rootId: Hash, level: Int, result: inout [String]) {
    let indent = String(repeating: "  ", count: level)
    if let nodeType = nodeInfo[rootId] {
      result.append("\(indent)[\(rootId): \(nodeType)]")
    }

    if let children = layout.tree[rootId], !children.isEmpty {
      for childId in children {
        displayTree(rootId: childId, level: level + 1, result: &result)
      }
    }
  }

  private func foregroundColor(_ color: Color) -> String {
    let rgb = color.rgb()
    return "rgb(\(Int(rgb.r * 255)),\(Int(rgb.g * 255)),\(Int(rgb.b * 255)))"
  }

  private func displayNodeInfo(id: Hash, result: inout [String]) {
    result.append("\(id): \(nodeInfo[id]!)")

    if let pos = layout.positions[id] {
      result.append("  Position: (\(pos.x), \(pos.y))")
    }

    if let container = layout.sizes[id] {
      result.append("  Size: \(container.width) x \(container.height)")
      result.append("  Orientation: \(container.orientation)")
    }

    if let attrs = layout.attributes[id] {
      let attrsInfo = attrs.dumpAttributes()
      result.append(attrsInfo)
    }

    if let children = layout.tree[id], !children.isEmpty {
      result.append("  Children: [\(children.map(String.init).joined(separator: ", "))]")
    }
  }

  mutating func before(_ block: some Block) {
    var description = "\(type(of: block))"
    if let attributedBlock = block as? AttributedBlock<Text> {
      description += " \"\(attributedBlock.wrapped.label)\""
    }
    nodeInfo[currentId] = description
  }
  mutating func after(_ block: some Block) {}
  mutating func before(child block: some Block) {}
  mutating func after(child block: some Block) {}
}

extension Attributes {
  func dumpAttributes() -> String {
    var parts: [String] = []

    parts.append("width: \(width)")
    parts.append("height: \(height)")

    if let foreground = foreground {
      parts.append("foreground: \(foreground)")
    }

    if let background = background {
      parts.append("background: \(background)")
    }

    if let borderColor = borderColor {
      parts.append("borderColor: \(borderColor)")
    }

    if let borderWidth = borderWidth {
      parts.append("borderWidth: \(borderWidth)")
    }

    if let borderRadius = borderRadius {
      parts.append("borderRadius: \(borderRadius)")
    }

    if let scale = scale {
      parts.append("scale: \(scale)")
    }

    if let padding = padding {
      let paddingStr =
        "padding: (top: \(padding.top ?? 0), right: \(padding.right ?? 0), bottom: \(padding.bottom ?? 0), left: \(padding.left ?? 0))"
      parts.append(paddingStr)
    }
    return "Attributes(\(parts.joined(separator: ", ")))"
  }
}
