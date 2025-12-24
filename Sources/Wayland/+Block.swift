import Logging

struct InternalGroup: BlockGroup, OrientationBlock, Block {
  let orientation: Orientation
  let children: [any Block]
}

@MainActor
public protocol Walker {
  var currentId: Hash { get set }
  mutating func before(_ block: some Block)
  mutating func after(_ block: some Block)
}

extension Block {
  func id(_ index: Int? = nil) -> UInt64 {
    if let index {
      return hash("\(type(of: self))\(index)")
    }
    return hash("\(type(of: self))")
  }

  public func walk(with walker: inout some Walker) {
    let prev = walker.currentId
    if let o = self as? OrientationBlock {
      walker.currentId = self.id()
      walker.before(self)
      self.layer.walk(with: &walker)
      walker.after(self)
    } else if let group = self as? BlockGroup {
      for (i, child) in group.children.enumerated() {
        walker.currentId = child.id(i)
        walker.before(self)
        child.walk(with: &walker)
        walker.after(self)
      }
    } else if let rect = self as? Rect {
      walker.currentId = self.id()
      walker.before(self)
      walker.after(self)
    } else if let word = self as? Word {
      walker.currentId = self.id()
      walker.before(self)
      walker.after(self)
    } else {  // Composed
      walker.currentId = self.id()
      walker.before(self)
      self.layer.walk(with: &walker)
      walker.after(self)
    }
    walker.currentId = prev
  }
}
