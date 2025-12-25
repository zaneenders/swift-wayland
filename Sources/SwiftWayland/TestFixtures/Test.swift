import Wayland

struct Test1: Block {
  let o: Orientation
  let names = ["Tyler", "Mel"]
  var layer: some Block {
    Group(o) {
      Word(names[0]).scale(4)
        .forground(.yellow)
      Word(names[1]).scale(4)
        .background(.pink)
    }
  }
}

struct Test2: Block {
  let scale: UInt = 8
  var layer: some Block {
    Group(.horizontal) {
      Word("Left").scale(scale)
      Group(.vertical) {
        Word("Top").scale(scale)
        Group(.horizontal) {
          for a in 0..<5 {
            if a.isMultiple(of: 2) {
              Word("\(a)").scale(scale)
            }
          }
        }
        Word("Bottom").scale(scale)
      }
      Word("Right").scale(scale)
    }
  }
}
