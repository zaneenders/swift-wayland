import Foundation
import ShapeTree

public struct SystemToolbar: Block {

  let batteryColor: Color
  let battery: String
  var time: String
  let scale: UInt = 2

  public var layer: some Block {
    // TODO: Could the height be specified here and passed in here instead of hardcoded to 20
    Direction(.horizontal) {
      Text(battery)
        .scale(scale)
        .foreground(batteryColor)
      Rect()  // Spacer
        .width(.grow)
      Text(time).scale(scale)
        .foreground(.teal)
        .background(.black)
    }
  }

  public init(battery: String, batteryColor: Color, time: String) {
    self.time = time
    self.battery = battery
    self.batteryColor = batteryColor
  }

  public init(battery: String, batteryColor: Color) {
    self.battery = battery
    self.batteryColor = batteryColor
    let formatter = DateFormatter()
    formatter.dateFormat = "yy-MM-dd HH:mm:ss"
    self.time = formatter.string(from: Date())
  }
}
