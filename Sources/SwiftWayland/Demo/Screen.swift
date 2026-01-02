import Wayland

struct Screen: Block {
  let ips: [String]
  var layer: some Block {
    Direction(.vertical) {  // TODO: This group should be implict
      Layout()
      for ip in ips {
        Text(ip).scale(4)
          .forground(.white)
          .background(.random)
      }
      Borders()
    }
  }
}
