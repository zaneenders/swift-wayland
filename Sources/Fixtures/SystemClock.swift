import Foundation
import ShapeTree

public struct SystemClock: Block {

  public init(time: String) {
    self.time = time
  }

  public init() {
    let formatter = DateFormatter()
    formatter.dateFormat = "yy-MM-dd HH:mm:ss"
    self.time = formatter.string(from: Date())
  }

  var time: String
  public var layer: some Block {
    // TODO: Could the height be specified here and passed in here instead of hardcoded to 20
    Direction(.horizontal) {
      // BUG: Should place text on right side of the screen
      Rect()
        .width(.grow)
      Text(time).scale(2)
        .foreground(.teal)
        .background(.black)
    }
  }
}
