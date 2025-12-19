extension Block {
  public func draw(_ renderer: inout LayoutMachine) {
    if let orientation = self as? OrientationBlock {
      renderer.select(hashing: #function + "\(type(of:orientation))")
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
      renderer.select(hashing: #function + "\(type(of:rect))")
      renderer.consume(rect: rect)
    } else if let word = self as? Word {
      renderer.select(hashing: #function + "\(type(of:word))")
      renderer.consume(word: word)
    } else if let group = self as? BlockGroup {
      renderer.select(hashing: #function + "\(type(of:group))")
      for block in group.children {
        block.draw(&renderer)
      }
    } else {
      renderer.select(hashing: #function + "\(type(of: self))")
      self.layer.draw(&renderer)
    }
  }
}
