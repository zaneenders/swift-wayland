import Wayland

struct Borders: Block {
  let scale: UInt
  var layer: some Block {
    Direction(.horizontal) {
      Direction(.vertical) {
        Text("Sharp")
          .scale(scale)
        Rect()
          .width(.fixed(40 * scale))
          .height(.fixed(30 * scale))
          .background(.blue)
          .border(width: 8)
          .border(color: .pink)
          .border(radius: 0)
      }
      Direction(.vertical) {
        Text("Rounded")
          .scale(scale)
        Rect()
          .width(.fixed(40 * scale))
          .height(.fixed(30 * scale))
          .background(.green)
          .border(width: 6)
          .border(color: .red)
          .border(radius: 8)
      }
      Direction(.vertical) {
        Text("Smooth")
          .scale(scale)
        Rect()
          .width(.fixed(40 * scale))
          .height(.fixed(30 * scale))
          .background(.purple)
          .border(width: 4)
          .border(color: .yellow)
          .border(radius: 15)
      }
    }
  }
}
