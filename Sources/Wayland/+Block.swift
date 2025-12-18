extension Block {
  func draw(_ renderer: inout Renderer) {
    if renderer.selected == 0 {
      renderer.select(hash(#function + "\(self)"))
    }
    if let orientation = self as? OrientationBlock {
      let chagned = renderer.orientation != orientation.orientation
      if chagned {
        renderer.orientation = orientation.orientation
        renderer.pushLayer(renderer.orientation)
      }
      self.layer.draw(&renderer)
      if chagned {
        renderer.popLayer()
      }
    } else if let rect = self as? Rect {
      renderer.consume(rect: rect)
    } else if let word = self as? Word {
      renderer.consume(word: word)
    } else if let group = self as? BlockGroup {
      for block in group.children {
        block.draw(&renderer)
      }
      renderer.frameInfo()
    } else {
      self.layer.draw(&renderer)
    }
  }
}
