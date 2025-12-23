import Logging

extension Block {
  public func moveDown(_ renderer: inout LayoutMachine) {
    let logger = Logger.create(logLevel: .trace)
    logger.notice("\(#function)")
    var moveDown = MoveDown(selected: renderer.selected, prev: id)
    self.moveDown(&moveDown)
    guard let new = moveDown.new else {
      logger.warning("Did not move down")
      return
    }
    renderer.selected = new
  }

  func moveDown(_ move: inout MoveDown) {
    if self as? OrientationBlock != nil {
      self.layer.moveDown(&move)
      move.prev = id
    } else if (self as? Rect != nil) || (self as? Word != nil) {
      // Leaf Node
    } else if let group = self as? BlockGroup {
      for (i, block) in group.children.enumerated() {
        if i + 1 == move.index {
          move.new = id
        }
        if move.new == nil && move.selected == id {
          move.index = i
        }
        block.moveDown(&move)
      }
      move.prev = id
    } else {
      self.layer.moveDown(&move)
      move.prev = id
    }
  }
}

struct MoveDown {
  let selected: Hash
  var new: Hash?
  var prev: Hash
  var index: Int?
}
