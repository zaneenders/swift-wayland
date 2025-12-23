import Logging

extension Block {
  public func moveIn(_ renderer: inout LayoutMachine) {
    let logger = Logger.create(logLevel: .trace)
    logger.notice("\(#function)")
    var moveIn = MoveIn(selected: renderer.selected)
    self.moveIn(&moveIn)
    guard let new = moveIn.new else {
      logger.warning("Did not move in")
      return
    }
    renderer.selected = new
  }

  func moveIn(_ move: inout MoveIn) {
    if move.next {
      move.new = id
    }
    move.next = id == move.selected && move.new == nil
    if self as? OrientationBlock != nil {
      self.layer.moveIn(&move)
    } else if (self as? Rect != nil) || (self as? Word != nil) {
      // Leaf Node
      if move.new == nil {
        move.new = move.selected
      }
    } else if let group = self as? BlockGroup {
      for block in group.children {
        block.moveIn(&move)
      }
    } else {
      self.layer.moveIn(&move)
    }
  }
}
struct MoveIn {
  let selected: Hash
  var new: Hash?
  var next = false
}
