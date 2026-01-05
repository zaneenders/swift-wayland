import Wayland

struct Screen: Block {
  let scale: UInt
  let ips: [String]
  var layer: some Block {
    Direction(.vertical) {  // TODO: This group should be implict
      EmptyBlock()
      Text("Zane was here")
        .scale(scale)
        .foreground(.cyan)
      Layout(scale: scale)
      for ip in ips {
        Text(ip).scale(4)
          .foreground(.black)
          .background(.random)
      }
      Borders(scale: scale)
      Rect()
    }
  }
}

struct EmptyBlock: Block {
  var layer: some Block {}
}
