import Wayland

struct Borders: Block {
  var layer: some Block {
    Direction(.horizontal) {
      Direction(.vertical) {
        Text("Sharp").scale(2).forground(.white)
        Rect(width: 40, height: 30, color: .blue, scale: 2, borderWidth: 8, borderColor: .pink, cornerRadius: 0)
      }
      Direction(.vertical) {
        Text("Rounded").scale(2).forground(.white)
        Rect(width: 40, height: 30, color: .green, scale: 2, borderWidth: 6, borderColor: .red, cornerRadius: 8)
      }
      Direction(.vertical) {
        Text("Smooth").scale(2).forground(.white)
        Rect(width: 40, height: 30, color: .purple, scale: 2, borderWidth: 4, borderColor: .yellow, cornerRadius: 15)
      }
    }
  }
}
