import Logging

extension Block {

  public func moveUp(_ renderer: inout LayoutMachine) {
    let logger = Logger.create(logLevel: .trace)
    logger.notice("\(#function)")
    var moveUp = MoveUp(selected: renderer.selected, last: id())
    self.moveUp(&moveUp, self.id())
    guard let new = moveUp.new else {
      logger.warning("Did not move up")
      return
    }
    renderer.selected = new
  }

  func moveUp(_ move: inout MoveUp, _ hash: UInt64) {
    if self as? OrientationBlock != nil {
      self.layer.moveUp(&move, self.layer.id())
      move.last = id()
    } else if (self as? Rect != nil) || (self as? Word != nil) {
      // Leaf Node
      move.last = id()
    } else if let group = self as? BlockGroup {
      // BUG: This is broken.
      for (i, block) in group.children.enumerated() {
        if hash == move.selected && move.new == nil {
          move.new = move.last
        }
        move.last = hash
        block.moveUp(&move, block.id(i))
      }
    } else {
      self.layer.moveUp(&move, self.layer.id())
      move.last = hash
    }
  }
}

struct MoveUp {
  let selected: Hash
  var new: Hash?
  var last: Hash
}
