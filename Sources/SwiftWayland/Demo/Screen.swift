import Wayland

struct Screen: Block {
  let ips: [String]
  let fps: String

  init(ips: [String], fps: String = "") {
    self.ips = ips
    self.fps = fps
  }

  var layer: some Block {
    Direction(.vertical) {  // TODO: This group should be implict
      EmptyBlock()
      if !fps.isEmpty {
        Text(fps)
          .foreground(.green)
      }
      Text("Zane was here")
        .foreground(.cyan)
      Layout()
      for ip in ips {
        Text(ip).scale(4)
          .foreground(.black)
          .background(.random)
      }
      Borders()
      Rect()
    }
  }
}

struct EmptyBlock: Block {
  var layer: some Block {}
}
