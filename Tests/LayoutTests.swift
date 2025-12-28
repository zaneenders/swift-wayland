import Testing

@testable import SwiftWayland
@testable import Wayland

@MainActor
@Test
func layout() {
  var sizer = SizeWalker()
  let test = LayoutTest()
  test.walk(with: &sizer)
  let root = sizer.tree[0]![0]
  #expect(sizer.elements[root]! == .known(height: 84, width: 348, .vertical))
}

enum Size: Equatable, CustomStringConvertible {
  case unknown(Orientation)
  case known(height: UInt, width: UInt, Orientation)

  var description: String {
    switch self {
    case .unknown(let o):
      return "unknown: \(o)"
    case .known(height: let h, width: let w, let o):
      return "height: \(h), width: \(w), orientation: \(o)"
    }
  }
}

struct SizeWalker: Walker {
  var currentId: Hash = 0
  var parentId: Hash = 0
  var elements: [Hash: Size] = [:]
  var parents: [Hash: Hash] = [:]
  var names: [Hash: String] = [:]
  var currentOrentation: Orientation = .vertical
  var tree: [Hash: [Hash]] = [:]

  mutating func connect(parent: Hash, current: Hash) {
    if var sibilings = tree[parent] {
      sibilings.append(current)
      tree[parent] = sibilings
    } else {
      tree[parent] = [current]
    }
  }

  mutating func before(_ block: some Block) {
    names[currentId] = "\(type(of: block))"
    parents[currentId] = parentId
    connect(parent: parentId, current: currentId)
    if let rect = block as? Rect {
      let width = rect.width * rect.scale
      let height = rect.height * rect.scale
      elements[currentId] = .known(height: height, width: width, currentOrentation)
    } else if let text = block as? Word {
      guard !text.label.contains("\n") else {
        fatalError("New lines not supported yet")
      }
      elements[currentId] = .known(height: text.height, width: text.width, currentOrentation)
    } else if let group = block as? BlockGroup {
      if group.children.count < 1 {
        // Handle empty groups from optional blocks.
        elements[currentId] = .known(height: 0, width: 0, currentOrentation)
      } else {
        elements[currentId] = .unknown(currentOrentation)
      }
    } else if let o = block as? OrientationBlock {
      currentOrentation = o.orientation
      elements[currentId] = .unknown(currentOrentation)
    } else {
      // User defined composed
      elements[currentId] = .unknown(currentOrentation)
    }
  }

  mutating func after(_ block: some Block) {
    guard let p = elements[parentId], let me = elements[currentId] else { return }
    switch (p, me) {
    case (.unknown(let o), .known(height: let mh, width: let mw, _)):
      elements[parentId] = .known(height: mh, width: mw, o)
    case (.known(height: let h, width: let w, let o), .known(height: let mh, width: let mw, _)):
      switch o {
      case .horizontal:
        elements[parentId] = .known(height: max(mh, h), width: mw + w, o)
      case .vertical:
        elements[parentId] = .known(height: h + mh, width: max(mw, w), o)
      }
    case (.unknown, .unknown), (.known, .unknown):
      fatalError("Invalid tree construction")
    }
  }

  mutating func before(child block: some Block) {}
  mutating func after(child block: some Block) {}
}
