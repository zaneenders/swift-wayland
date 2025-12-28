import Wayland

/*
LeftTop   Right
    024
    Bottom
*/
struct LayoutTest: Block {
  let scale: UInt = 4
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
