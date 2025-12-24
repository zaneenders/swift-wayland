import Logging

extension Block {

  public func moveOut(_ renderer: inout LayoutMachine) {
    let logger = Logger.create(logLevel: .trace)
    logger.notice("\(#function)")
    var moveOut = MoveOut(selected: renderer.selected)
    self.moveOut(&moveOut, self.id())
    guard let new = moveOut.new else {
      logger.warning("Did not move out")
      return
    }
    renderer.selected = new
  }

  func moveOut(_ move: inout MoveOut, _ hash: UInt64) {
    if self as? OrientationBlock != nil {
      self.layer.moveOut(&move, self.layer.id())
    } else if (self as? Rect != nil) || (self as? Word != nil) {
      // Leaf Node
    } else if let group = self as? BlockGroup {
      for (i, block) in group.children.enumerated() {
        block.moveOut(&move, block.id(i))
      }
    } else {
      self.layer.moveOut(&move, self.layer.id())
    }
    if move.prev {
      move.new = hash
    }
    move.prev = hash == move.selected && move.new == nil
  }
}

struct MoveOut {
  let selected: Hash
  var new: Hash?
  var prev = false
}
