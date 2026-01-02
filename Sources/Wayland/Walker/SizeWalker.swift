enum Size: Equatable, CustomStringConvertible {
  case unknown(Orientation)
  case known(Container)

  var description: String {
    switch self {
    case .unknown(let o):
      return "unknown: \(o)"
    case .known(let container):
      return "height: \(container.height), width: \(container.width), orientation: \(container.orientation)"
    }
  }
}

struct Container: Equatable {
  let height: UInt
  let width: UInt
  let orientation: Orientation
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
      sizes[currentId] = .known(Container(height: height, width: width, orientation: currentOrentation))
    } else if let text = block as? Text {
      guard !text.label.contains("\n") else {
        fatalError("New lines not supported yet")
      }
      sizes[currentId] = .known(Container(height: text.height, width: text.width, orientation: currentOrentation))
    } else if let group = block as? BlockGroup {
      if group.children.count < 1 {
        // Handle empty groups from optional blocks.
        sizes[currentId] = .known(Container(height: 0, width: 0, orientation: currentOrentation))
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
    case (.unknown(let o), .known(let container)):
      sizes[parentId] = .known(Container(height: container.height, width: container.width, orientation: o))
    case (.known(let parentContainer), .known(let myContainer)):
      switch parentContainer.orientation {
      case .horizontal:
        sizes[parentId] = .known(
          Container(
            height: max(myContainer.height, parentContainer.height),
            width: myContainer.width + parentContainer.width,
            orientation: .horizontal))
      case .vertical:
        sizes[parentId] = .known(
          Container(
            height: myContainer.height + parentContainer.height,
            width: max(myContainer.width, parentContainer.width),
            orientation: .vertical))
      }
    case (.unknown, .unknown), (.known, .unknown):
      fatalError("Invalid tree construction")
    }
  }

  mutating func before(child block: some Block) {}
  mutating func after(child block: some Block) {}
}
