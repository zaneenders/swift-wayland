import Wayland

struct Screen: Block {

  let o: Orientation
  let ips: [String]

  var layer: some Block {
    Group(o) {
      Rect(width: 5, height: 5, color: .pink, scale: 8)
      Word("Demo")
        .forground(.green)
        .background(.purple)
      for ip in ips {
        Word(ip).scale(4)
          .forground(.white)
          .background(.random)
      }
    }
  }
}
