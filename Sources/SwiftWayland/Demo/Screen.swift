import Wayland

struct Screen: Block {
  let ips: [String]
  var layer: some Block {
    Group(.vertical) {  // TODO: This group should be implict
      Layout()
      for ip in ips {
        Word(ip).scale(4)
          .forground(.white)
          .background(.random)
      }
      Borders()
    }
  }
}
