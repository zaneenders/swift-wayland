import ShapeTree

public struct PaddedText: Block {
  let text: String
  let padding: UInt
  let foreground: Color
  let background: Color

  public init(text: String, padding: UInt, foreground: Color, background: Color) {
    self.text = text
    self.padding = padding
    self.foreground = foreground
    self.background = background
  }

  public var layer: some Block {
    // BUG: Should not have default background color
    Text(text)
      .scale(2)
      .padding(padding)
      .foreground(foreground)
      .background(background)
  }
}

public struct Screen: Block {
  let scale: UInt
  let ips: [String]
  let fps: String

  public init(scale: UInt, ips: [String], fps: String = "") {
    self.scale = scale
    self.ips = ips
    self.fps = fps
  }

  public var layer: some Block {
    Direction(.vertical) {  // TODO: This group should be implicit
      EmptyBlock()
      Direction(.horizontal) {
        // BUG: Should place PaddedText on right hand side
        EmptyBlock().width(.grow)
        if !fps.isEmpty {
          // NOTE: This is a little bit verbose for text with colored padding around it.
          PaddedText(text: fps, padding: 5, foreground: .black, background: .green)
            .background(.green)
        }
      }
      Text("Zane was here")
        .scale(scale)
        .foreground(.cyan)
        .padding(15)
      Layout(scale: scale)
      for ip in ips {
        Text(ip).scale(4)
          .foreground(.random)
          .background(.white)
          .padding(5)
      }
      Borders(scale: scale)
      Rect()
        .background(.orange)
        .width(.grow)
        .height(.grow)
    }
    .background(.pink)
    .height(.grow)
    .width(.grow)
  }
}

public struct EmptyBlock: Block {
  public init() {}
  public var layer: some Block {}
}
