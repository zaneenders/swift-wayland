import Logging

extension Block {

  public func moveDown(_ renderer: inout LayoutMachine) {
    let logger = Logger.create(logLevel: .trace)
    logger.notice("\(#function)")
    var moveDown = MoveDown(selected: renderer.selected, prev: id())
    self.moveDown(&moveDown, self.id())
    guard let new = moveDown.new else {
      logger.warning("Did not move down")
      return
    }
    renderer.selected = new
  }

  func moveDown(_ move: inout MoveDown, _ hash: UInt64) {
    if self as? OrientationBlock != nil {
      self.layer.moveDown(&move, self.layer.id())
      move.prev = id()
    } else if (self as? Rect != nil) || (self as? Word != nil) {
      // Leaf Node
    } else if let group = self as? BlockGroup {
      print("\(type(of: self)), \(hash), \(move)")
      for (i, block) in group.children.enumerated() {
        let blockID = block.id(i)
        if i + 1 == move.index {
          move.new = blockID
        }
        if move.new == nil && move.selected == blockID {
          move.index = i
        }
        print("\(type(of: self)), \(blockID) \(i), \(move)")
        block.moveDown(&move, blockID)
        move.prev = blockID
      }
      move.prev = id()
    } else {
      self.layer.moveDown(&move, self.layer.id())
      move.prev = id()
    }
  }
}

struct MoveDown {
  let selected: Hash
  var new: Hash?
  var prev: Hash
  var index: Int?
}
