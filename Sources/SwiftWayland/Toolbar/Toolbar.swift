#if Toolbar
import ShapeTree
import Foundation
import Wayland
import Fixtures

@MainActor
func runToolbar() async {
  let formatter = DateFormatter()
  formatter.dateFormat = "yy-MM-dd HH:mm:ss"

  Wayland.setup()
  event_loop: for await ev in Wayland.events() {
    switch ev {
    case .frame(let winH, let winW):
      Wayland.preDraw()
      let today = formatter.string(from: Date())
      let block = SystemClock(time: today)
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
#endif
