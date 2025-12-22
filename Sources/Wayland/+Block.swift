import Logging

extension Block {
  public func draw(_ renderer: inout LayoutMachine, selected: Bool = false) {
    let id = "\(type(of:self))"
    if renderer.selected == 0 {
      renderer.selct(hashing: id)
    }
    renderer.current(hashing: id)
    let selectedPath = renderer.currentSelected || selected
    if let orientation = self as? OrientationBlock {
      let chagned = renderer.orientation != orientation.orientation
      if chagned {
        renderer.orientation = orientation.orientation
        renderer.pushLayer(renderer.orientation)
      }
      self.layer.draw(&renderer, selected: selectedPath)
      if chagned {
        renderer.popLayer()
      }
    } else if let rect = self as? Rect {
      renderer.consume(rect: rect, selected: selectedPath)
    } else if let word = self as? Word {
      renderer.consume(word: word, selected: selectedPath)
    } else if let group = self as? BlockGroup {
      for block in group.children {
        block.draw(&renderer, selected: selectedPath)
      }
    } else {
      self.layer.draw(&renderer, selected: selectedPath)
    }
  }

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
    let id = "\(type(of:self))"
    move.current(hashing: id)
    if move.next {
      move.new = move.current
    }
    move.next = move.current == move.selected && move.new == nil
    if self as? OrientationBlock != nil {
      self.layer.moveIn(&move)
    } else if self as? Rect != nil {
      // Leaf Node
    } else if self as? Word != nil {
      // Leaf Node
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
  var current: Hash = 0
  var new: Hash?
  var next = false

  mutating func current(hashing string: String) {
    let prev = self.current
    let h = hash(string)
    let hash = hash(prev ^ h)  // Not sure what operation to do here.
    self.current = hash
  }
}
