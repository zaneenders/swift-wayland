import Wayland

struct Layout: Block {
  let scale: UInt
  var layer: some Block {
    Direction(.horizontal) {
      Rect()
        .width(25 * scale)
        .height(25 * scale)
        .background(.yellow)
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
            .width(25 * scale)
            .height(25 * scale)
            .background(.magenta)
          Text("Bottom").scale(scale)
        }
        Text("Right").scale(scale)
      }
      Rect()
        .width(25 * scale)
        .height(25 * scale)
        .background(.cyan)
    }
  }
}
