import Wayland

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
      if !fps.isEmpty {
        Text(fps)
          .foreground(.green)
          .padding(5)
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
