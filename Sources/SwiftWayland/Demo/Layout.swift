import Wayland

struct Layout: Block {
  let scale: UInt = 2
  var layer: some Block {
    Direction(.horizontal) {
      Rect()
        .width(25)
        .height(25)
        .background(.yellow)
        .scale(5)
      Direction(.horizontal) {
        Text("Left").scale(scale)
        Direction(.vertical) {
          Text("Top").scale(scale)
          Direction(.horizontal) {
            for a in 0..<5 {
              if a.isMultiple(of: 2) {
                Text("\(a)").scale(scale)
              }
            }
          }
          Rect()
            .width(25)
            .height(25)
            .background(.magenta)
            .scale(5)
          Text("Bottom").scale(scale)
        }
        Text("Right").scale(scale)
      }
      Rect()
        .width(25)
        .height(25)
        .background(.cyan)
        .scale(5)
    }
  }
}
