import Wayland

struct LayoutTest: Block {
  let scale: UInt = 4
  var layer: some Block {
    Rect(width: 25, height: 25, color: .magenta, scale: 5)
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
