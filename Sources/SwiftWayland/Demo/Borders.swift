import Wayland

struct Borders: Block {
  var layer: some Block {
    Group(.horizontal) {
      Rect(width: 30, height: 20, color: .blue, scale: 2, borderWidth: 9, borderColor: .pink)
      Rect(width: 30, height: 20, color: .green, scale: 2, borderWidth: 3, borderColor: .red)
      Rect(width: 30, height: 20, color: .purple, scale: 2, borderWidth: 5, borderColor: .yellow)
    }
  }
}
