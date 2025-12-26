import Logging

@MainActor
public protocol Walker {
  var currentId: Hash { get set }
  mutating func before(_ block: some Block)
  mutating func after(_ block: some Block)
  mutating func before(child block: some Block)
  mutating func after(child block: some Block)
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
        let prev = walker.currentId
        walker.currentId = child.id(current: walker.currentId, i)
        walker.before(child: child)
        child._walk(with: &walker, orientation)
        walker.after(child: child)
        walker.currentId = prev
      }
    } else if let rect = self as? Rect {
    } else if let word = self as? Word {
    } else {  // Composed
      self.layer.walk(with: &walker, orientation)
    }
    walker.after(self)
  }

  public func walk(with walker: inout some Walker, _ orientation: Orientation = .vertical) {
    let prev = walker.currentId
    walker.currentId = self.id(current: walker.currentId)
    _walk(with: &walker, orientation)
    walker.currentId = prev
  }
}
