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
  let settings: FontMetrics
  let scale: UInt

  init(settings: FontMetrics, attributes: [Hash: Attributes], logLevel: Logger.Level = .trace) {
    self.settings = settings
    self.attributes = attributes
    self.logger = Logger.create(logLevel: logLevel, label: "SizeWalker")
    self.scale = 1
  }

  mutating func before(_ block: some Block) {
    names[currentId] = "\(type(of: block))"
    parents[currentId] = parentId

    if let attributes = attributes[currentId] {
      apply(attributes: attributes, block)
    } else if block is any HasAttributes {
      // Skip over attributes blocks
    } else if let text = block as? Text {
      guard !text.label.contains("\n") else {
        fatalError("New lines not supported yet")
      }
      sizes[currentId] = .known(
        Container(
          height: text.height(1, using: settings),
          width: text.width(1, using: settings),
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
      width = text.width(attributes.scale ?? scale, using: settings)
      height = text.height(attributes.scale ?? scale, using: settings)
    } else {
      switch attributes.width {
      case .fixed(let w):
        width = w
      case .grow:
        width = 0
      case .fit:
        width = 0
      }

      switch attributes.height {
      case .fixed(let h):
        height = h
      case .grow:
        height = 0
      case .fit:
        height = 0
      }
    }
    if let padding = attributes.padding {
      width += (padding.left ?? 0) + (padding.right ?? 0)
      height += (padding.top ?? 0) + (padding.bottom ?? 0)
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

public struct Container: Equatable {
  public var height: UInt
  public var width: UInt
  public var orientation: Orientation

  public init(height: UInt, width: UInt, orientation: Orientation) {
    self.height = height
    self.width = width
    self.orientation = orientation
  }
}
