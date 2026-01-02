import Wayland

struct Borders: Block {
  var layer: some Block {
    Group(.horizontal) {
      Group(.vertical) {
        Word("Sharp").scale(2).forground(.white)
        Rect(width: 40, height: 30, color: .blue, scale: 2, borderWidth: 8, borderColor: .pink, cornerRadius: 0)
      }
      Group(.vertical) {
        Word("Rounded").scale(2).forground(.white)
        Rect(width: 40, height: 30, color: .green, scale: 2, borderWidth: 6, borderColor: .red, cornerRadius: 8)
      }
      Group(.vertical) {
        Word("Smooth").scale(2).forground(.white)
        Rect(width: 40, height: 30, color: .purple, scale: 2, borderWidth: 4, borderColor: .yellow, cornerRadius: 15)
      }
    }
  }
}
