import Wayland

struct PaddedText: Block {
  let text: String
  let padding: UInt
  var layer: some Block {
    // BUG: Should not have default background color
    Text(text)
      .padding(padding)
  }
}

struct Screen: Block {
  let scale: UInt
  let ips: [String]
  let fps: String

  init(scale: UInt, ips: [String], fps: String = "") {
    self.scale = scale
    self.ips = ips
    self.fps = fps
  }

  var layer: some Block {
    Direction(.vertical) {  // TODO: This group should be implict
      EmptyBlock()
      Direction(.horizontal) {
        // BUG: Should place PaddedText on right hand side
        EmptyBlock().width(.grow)
        if !fps.isEmpty {
          PaddedText(text: fps, padding: 5)
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

struct EmptyBlock: Block {
  var layer: some Block {}
}
