import Logging

extension Block {
  func id(_ index: Int? = nil) -> UInt64 {
    if let index {
      return hash("\(type(of: self))\(index)")
    }
    return hash("\(type(of: self))")
  }

  public func draw(_ renderer: inout LayoutMachine, selected: Bool = false) {
    if renderer.selected == 0 {
      renderer.selected = id()
    }
    renderer.current = id()
    let isSelected = renderer.currentSelected || selected
    if let orientation = self as? OrientationBlock {
      let chagned = renderer.orientation != orientation.orientation
      if chagned {
        renderer.orientation = orientation.orientation
        renderer.pushLayer(renderer.orientation)
      }
      self.layer.draw(&renderer, selected: isSelected)
      if chagned {
        renderer.popLayer()
      }
    } else if let rect = self as? Rect {
      renderer.consume(rect: rect, selected: isSelected)
    } else if let word = self as? Word {
      renderer.consume(word: word, selected: isSelected)
    } else if let group = self as? BlockGroup {
      for block in group.children {
        block.draw(&renderer, selected: isSelected)
      }
    } else {
      self.layer.draw(&renderer, selected: isSelected)
    }
  }
}
