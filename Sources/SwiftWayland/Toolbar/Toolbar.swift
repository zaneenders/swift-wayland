#if Toolbar
import ShapeTree
import Foundation
import Wayland
import Fixtures

@MainActor
func runToolbar() async {
  let formatter = DateFormatter()
  formatter.dateFormat = "yy-MM-dd HH:mm:ss"

  let system = SystemState()
  Wayland.setup()
  event_loop: for await ev in Wayland.events() {
    switch ev {
    case .frame(let winH, let winW):
      Wayland.preDraw()
      let bp = await system.view().batteryPercent
      let battery = "\(bp)%"
      let today = formatter.string(from: Date())
      let block = SystemClock(battery: battery, batteryColor: bp.batteryColor, time: today)
      Wayland.render(block)
      Wayland.postDraw()
    }
  }

  // Read the final state
  switch Wayland.state {
  case .error(let reason):
    print("error: \(reason)")
  case .running, .exit:
    ()
  }
}

extension Int {
  fileprivate var batteryColor: Color {
    switch self {
    case 69: .pink
    case -1..<20: .red
    case 20..<50: .orange
    case 50..<80: .yellow
    default: .green
    }
  }
}
#endif
