import Logging

extension Block {
  public func moveIn(_ renderer: inout LayoutMachine) {
    let logger = Logger.create(logLevel: .trace)
    logger.notice("\(#function)")
    var moveIn = MoveIn(selected: renderer.selected)
    self.moveIn(&moveIn, self.id())
    guard let new = moveIn.new else {
      logger.warning("Did not move in")
      return
    }
    renderer.selected = new
  }

  func moveIn(_ move: inout MoveIn, _ hash: UInt64) {
    if move.next {
      move.new = hash
    }
    move.next = hash == move.selected && move.new == nil
    if self as? OrientationBlock != nil {
      self.layer.moveIn(&move, layer.id())
    } else if (self as? Rect != nil) || (self as? Word != nil) {
      // Leaf Node
      if move.new == nil {
        move.new = move.selected
      }
    } else if let group = self as? BlockGroup {
      for (i, block) in group.children.enumerated() {
        block.moveIn(&move, block.id(i))
      }
    } else {
      self.layer.moveIn(&move, self.layer.id())
    }
  }
}

struct MoveIn {
  let selected: Hash
  var new: Hash?
  var next = false
}
