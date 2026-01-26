import Fixtures
import Testing

@testable import ShapeTree
@testable import Wayland

@MainActor
@Test func demoVisulizeWalker() {
  let block = SystemToolbar(battery: "69%", batteryColor: .pink, time: "time")
  print(block.visualize)
}
