import Wayland

struct Layout: Block {
  let scale: UInt = 2
  var layer: some Block {
    Group(.horizontal) {
      Rect(width: 25, height: 25, color: .yellow, scale: 5)
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
          Rect(width: 25, height: 25, color: .magenta, scale: 5)
          Word("Bottom").scale(scale)
        }
        Word("Right").scale(scale)
      }
      Rect(width: 25, height: 25, color: .cyan, scale: 5)
    }
  }
}
