import Wayland

struct Borders: Block {
  var layer: some Block {
    Direction(.horizontal) {
      Direction(.vertical) {
        Text("Sharp")
        Rect()
          .width(40)
          .height(30)
          .background(.blue)
          .border(width: 8)
          .border(color: .pink)
          .border(radius: 0)
      }
      Direction(.vertical) {
        Text("Rounded")
        Rect()
          .width(40)
          .height(30)
          .background(.green)
          .border(width: 6)
          .border(color: .red)
          .border(radius: 8)
      }
      Direction(.vertical) {
        Text("Smooth")
        Rect()
          .width(40)
          .height(30)
          .background(.purple)
          .border(width: 4)
          .border(color: .yellow)
          .border(radius: 15)
      }
    }
  }
}
