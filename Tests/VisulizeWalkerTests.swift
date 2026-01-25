import Fixtures
import Testing

@testable import ShapeTree
@testable import Wayland

@MainActor
@Test func demoVisulizeWalker() {
  let block = SystemToolBar(battery: "69%", batteryColor: .pink)
  let layout = calculateLayout(block)
  var viz = VisualizeWalker(layout: layout)
  block.walk(with: &viz)
  print(viz.display())
}
