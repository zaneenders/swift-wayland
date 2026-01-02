import Logging

@MainActor
protocol Walker {
  var currentId: Hash { get set }
  var parentId: Hash { get set }
  mutating func before(_ block: some Block)
  mutating func after(_ block: some Block)
  mutating func before(child block: some Block)
  mutating func after(child block: some Block)
}

@MainActor
extension Wayland {
  public static func render(_ block: some Block, logLevel: Logger.Level = .warning) {
    Wayland.preDraw()
    var sizer = SizeWalker()
    block.walk(with: &sizer)
    var positioner = PositionWalker(sizes: sizer.sizes.convert())
    block.walk(with: &positioner)
    var renderer = RenderWalker(positions: positioner.positions, Wayland.self, logLevel: logLevel)
    block.walk(with: &renderer)
    Wayland.postDraw()
  }
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

  func _walk(with walker: inout some Walker, _ orientation: Orientation) {
    walker.before(self)
    if let o = self as? OrientationBlock {
      self.layer.walk(with: &walker, o.orientation)
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
    } else if (self as? Rect != nil) || (self as? Text != nil) {
      // Leaf Nodes
    } else {  // Composed
      self.layer.walk(with: &walker, orientation)
    }
    walker.after(self)
  }

  func walk(with walker: inout some Walker, _ orientation: Orientation = .vertical) {
    let parent = walker.parentId
    walker.parentId = walker.currentId
    walker.currentId = self.id(current: walker.currentId)
    _walk(with: &walker, orientation)
    walker.currentId = walker.parentId
    walker.parentId = parent
  }
}
