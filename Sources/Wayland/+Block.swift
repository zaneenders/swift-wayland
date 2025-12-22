import Logging

extension Block {
  public func draw(_ renderer: inout LayoutMachine, selected: Bool = false) {
    if renderer.selected == 0 {
      renderer.selected = id
    }
    renderer.current = id
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
    if move.next {
      move.new = id
    }
    move.next = id == move.selected && move.new == nil
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
    } else if self as? Rect != nil {
      // Leaf Node
    } else if self as? Word != nil {
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

  var id: UInt64 {
    hash("\(type(of: self))")
  }
}

struct MoveOut {
  let selected: Hash
  var new: Hash?
  var prev = false
}

struct MoveIn {
  let selected: Hash
  var new: Hash?
  var next = false
}
