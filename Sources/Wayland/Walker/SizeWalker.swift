import Logging

@MainActor
struct SizeWalker: Walker {
  var currentId: Hash = 0
  var parentId: Hash = 0
  var sizes: [Hash: Size] = [:]
  var parents: [Hash: Hash] = [:]
  var names: [Hash: String] = [:]
  var currentOrentation: Orientation = .vertical
  var attributes: [Hash: Attributes]
  let logger: Logger

  init(attributes: [Hash: Attributes], logLevel: Logger.Level = .trace) {
    self.attributes = attributes
    self.logger = Logger.create(logLevel: logLevel, label: "SizeWalker")
  }

  mutating func before(_ block: some Block) {
    names[currentId] = "\(type(of: block))"
    parents[currentId] = parentId

    if let attributedBlock = block as? any HasAttributes {
      apply(attributes: attributedBlock.attributes, block)
    } else if let text = block as? Text {
      guard !text.label.contains("\n") else {
        fatalError("New lines not supported yet")
      }
      sizes[currentId] = .known(
        Container(
          height: text.height(defaultScale),
          width: text.width(defaultScale),
          orientation: currentOrentation))
    } else if let group = block as? BlockGroup {
      if group.children.count < 1 {
        // Handle empty groups from optional blocks.
        sizes[currentId] = .known(Container(height: 0, width: 0, orientation: currentOrentation))
      } else {
        sizes[currentId] = .unknown(currentOrentation)
      }
    } else if let group = block as? DirectionGroup {
      currentOrentation = group.orientation
      sizes[currentId] = .unknown(currentOrentation)
    } else {
      // User defined composed
      sizes[currentId] = .unknown(currentOrentation)
    }
  }

  private mutating func apply(attributes: Attributes, _ block: some Block) {
    var width: UInt = 0
    var height: UInt = 0

    if let text = block.layer as? Text {
      width = text.width(attributes.scale ?? defaultScale)
      height = text.height(attributes.scale ?? defaultScale)
    } else {
      if let attrWidth = attributes.width {
        width = attrWidth
      }
      if let attrHeight = attributes.height {
        height = attrHeight
      }
      if let scale = attributes.scale {
        width *= scale
        height *= scale
      }
    }

    sizes[currentId] = .known(Container(height: height, width: width, orientation: currentOrentation))
  }

  mutating func after(_ block: some Block) {
    guard let p = sizes[parentId], let me = sizes[currentId] else { return }
    switch (p, me) {
    case (.unknown(let o), .known(let container)):
      sizes[parentId] = .known(Container(height: container.height, width: container.width, orientation: o))
    case (.known(let parentContainer), .known(let myContainer)):
      switch parentContainer.orientation {
      case .horizontal:
        let newWidth = myContainer.width + parentContainer.width
        let newHeight = max(myContainer.height, parentContainer.height)

        sizes[parentId] = .known(
          Container(
            height: newHeight,
            width: newWidth,
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
