import Logging

@MainActor
public protocol Walker {
  var currentId: Hash { get set }
  var parentId: Hash { get set }
  mutating func before(_ block: some Block)
  mutating func after(_ block: some Block)
  mutating func before(child block: some Block)
  mutating func after(child block: some Block)
}

@MainActor
public func calculateLayout(_ block: some Block, height: UInt, width: UInt, settings: FontMetrics) -> Layout {
  var attributesWalker = AttributesWalker()
  block.walk(with: &attributesWalker)

  let root = attributesWalker.tree[0]![0]
  var sizer = SizeWalker(settings: settings, attributes: attributesWalker.attributes)
  block.walk(with: &sizer)

  let orientation: Orientation
  switch sizer.sizes[root]! {
  case .known(let container):
    orientation = container.orientation
  case .unknown(let o):
    orientation = o
  }
  sizer.sizes[root] = .known(Container(height: height, width: width, orientation: orientation))

  let containers = sizer.sizes.convert()
  // NOTE: Maybe instead of overiding the top level height and width I just pass them in here.
  var grower = GrowWalker(sizes: containers, attributes: attributesWalker.attributes)
  block.walk(with: &grower)

  var positioner = PositionWalker(sizes: grower.sizes, attributes: attributesWalker.attributes)
  block.walk(with: &positioner)

  return Layout(
    tree: attributesWalker.tree,
    attributes: attributesWalker.attributes,
    sizes: containers,
    computedSizes: grower.sizes,
    positions: positioner.positions
  )
}

extension [Hash: Size] {
  func convert() -> [Hash: Container] {
    var containers: [Hash: Container] = [:]
    for (key, value) in self {
      switch value {
      case .known(let container):
        containers[key] = container
      case .unknown(_):
        fatalError("\(#function) \(key) \(value)")
      }
    }
    return containers
  }
}

extension Block {
  func id(current: Hash, _ index: Int? = nil) -> UInt64 {
    // Not sure the best way to combine hashes together.
    if let index {
      return hash(current | hash("\(type(of: self))\(index)"))
    }
    return hash(current | hash("\(type(of: self))"))
  }

  private func _walk(with walker: inout some Walker, _ orientation: Orientation) {
    walker.before(self)
    if let group = self as? DirectionGroup {
      self.layer.walk(with: &walker, group.orientation)
    } else if let group = self as? BlockGroup {
      for (i, child) in group.children.enumerated() {
        let parent = walker.parentId
        walker.parentId = walker.currentId
        walker.currentId = child.id(current: walker.currentId, i)
        walker.before(child: child)
        child._walk(with: &walker, orientation)
        walker.after(child: child)
        walker.currentId = walker.parentId
        walker.parentId = parent
      }
    } else if self as? Text != nil {
      // Leaf Nodes
    } else if let attributedBlock = self as? any HasAttributes {
      if !(attributedBlock.layer is Text) {  // Prevents double rendering for now.
        self.layer.walk(with: &walker)
      }
    } else {  // Composed
      self.layer.walk(with: &walker, orientation)
    }
    walker.after(self)
  }

  public func walk(with walker: inout some Walker, _ orientation: Orientation = .vertical) {
    let parent = walker.parentId
    walker.parentId = walker.currentId
    walker.currentId = self.id(current: walker.currentId)
    _walk(with: &walker, orientation)
    walker.currentId = walker.parentId
    walker.parentId = parent
  }
}
