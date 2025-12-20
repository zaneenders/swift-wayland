extension Block {
  public func draw(_ renderer: inout LayoutMachine, selected: Bool = false) {
    let id = #function + "\(type(of:self))"
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
}
