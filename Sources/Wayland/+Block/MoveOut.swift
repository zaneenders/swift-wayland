import Logging

extension Block {
  public func moveOut(_ renderer: inout LayoutMachine) {
    let logger = Logger.create(logLevel: .trace)
    logger.notice("\(#function)")
    var moveOut = MoveOut(selected: renderer.selected)
    self.moveOut(&moveOut)
    guard let new = moveOut.new else {
      logger.warning("Did not move out")
      return
    }
    renderer.selected = new
  }

  func moveOut(_ move: inout MoveOut) {
    if self as? OrientationBlock != nil {
      self.layer.moveOut(&move)
    } else if (self as? Rect != nil) || (self as? Word != nil) {
      // Leaf Node
    } else if let group = self as? BlockGroup {
      for block in group.children {
        block.moveOut(&move)
      }
    } else {
      self.layer.moveOut(&move)
    }
    if move.prev {
      move.new = id
    }
    move.prev = id == move.selected && move.new == nil
  }
}

struct MoveOut {
  let selected: Hash
  var new: Hash?
  var prev = false
}
