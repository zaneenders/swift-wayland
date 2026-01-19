import ShapeTree
import Wayland

struct LeftPadding: Block {
  var layer: some Block {
    Direction(.horizontal) {
      Rect().width(.grow)
      Text("Right")
    }
  }
}
