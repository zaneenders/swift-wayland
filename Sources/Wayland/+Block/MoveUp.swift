import Logging

extension Block {
  public func moveUp(_ renderer: inout LayoutMachine) {
    let logger = Logger.create(logLevel: .trace)
    logger.notice("\(#function)")
    var moveUp = MoveUp(selected: renderer.selected, last: id)
    self.moveUp(&moveUp)
    guard let new = moveUp.new else {
      logger.warning("Did not move up")
      return
    }
    renderer.selected = new
  }

  func moveUp(_ move: inout MoveUp) {
    if self as? OrientationBlock != nil {
      self.layer.moveUp(&move)
      move.last = id
    } else if (self as? Rect != nil) || (self as? Word != nil) {
      // Leaf Node
      move.last = id
    } else if let group = self as? BlockGroup {
      for block in group.children {
        if id == move.selected && move.new == nil {
          move.new = move.last
        }
        move.last = id
        block.moveUp(&move)
      }
    } else {
      self.layer.moveUp(&move)
      move.last = id
    }
  }
}

struct MoveUp {
  let selected: Hash
  var new: Hash?
  var last: Hash
}
