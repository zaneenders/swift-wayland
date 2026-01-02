import Wayland

struct Borders: Block {
  var layer: some Block {
    Direction(.horizontal) {
      Direction(.vertical) {
        Text("Sharp").scale(2).forground(.white)
        Rect()
          .width(40)
          .height(30)
          .background(.blue)
          .scale(2)
          .border(width: 8)
          .border(color: .pink)
          .border(radius: 0)
      }
      Direction(.vertical) {
        Text("Rounded").scale(2).forground(.white)
        Rect()
          .width(40)
          .height(30)
          .background(.green)
          .scale(2)
          .border(width: 6)
          .border(color: .red)
          .border(radius: 8)
      }
      Direction(.vertical) {
        Text("Smooth").scale(2).forground(.white)
        Rect()
          .width(40)
          .height(30)
          .background(.purple)
          .scale(2)
          .border(width: 4)
          .border(color: .yellow)
          .border(radius: 15)
      }
    }
  }
}
