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

@MainActor
struct SizeWalker: Walker {
  var currentId: Hash = 0
  var parentId: Hash = 0
  var sizes: [Hash: Size] = [:]
  var parents: [Hash: Hash] = [:]
  var names: [Hash: String] = [:]
  var currentOrentation: Orientation = .vertical
  var tree: [Hash: [Hash]] = [:]
  var words: [Hash: Word] = [:]
  var quads: [Hash: Rect] = [:]

  init() {}

  private mutating func connect(parent: Hash, current: Hash) {
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
      sizes[currentId] = .known(height: height, width: width, currentOrentation)
      quads[currentId] = rect
    } else if let text = block as? Word {
      guard !text.label.contains("\n") else {
        fatalError("New lines not supported yet")
      }
      words[currentId] = text
      sizes[currentId] = .known(height: text.height, width: text.width, currentOrentation)
    } else if let group = block as? BlockGroup {
      if group.children.count < 1 {
        // Handle empty groups from optional blocks.
        sizes[currentId] = .known(height: 0, width: 0, currentOrentation)
      } else {
        sizes[currentId] = .unknown(currentOrentation)
      }
    } else if let o = block as? OrientationBlock {
      currentOrentation = o.orientation
      sizes[currentId] = .unknown(currentOrentation)
    } else {
      // User defined composed
      sizes[currentId] = .unknown(currentOrentation)
    }
  }

  mutating func after(_ block: some Block) {
    guard let p = sizes[parentId], let me = sizes[currentId] else { return }
    switch (p, me) {
    case (.unknown(let o), .known(height: let mh, width: let mw, _)):
      sizes[parentId] = .known(height: mh, width: mw, o)
    case (.known(height: let h, width: let w, let o), .known(height: let mh, width: let mw, _)):
      switch o {
      case .horizontal:
        sizes[parentId] = .known(height: max(mh, h), width: mw + w, o)
      case .vertical:
        sizes[parentId] = .known(height: h + mh, width: max(mw, w), o)
      }
    case (.unknown, .unknown), (.known, .unknown):
      fatalError("Invalid tree construction")
    }
  }

  mutating func before(child block: some Block) {}
  mutating func after(child block: some Block) {}
}
