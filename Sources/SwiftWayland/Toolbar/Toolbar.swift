#if Toolbar
import Foundation
import Wayland

struct SystemClock: Block {
  var time: String
  var layer: some Block {
    // TODO: Could the height be sepcified here and passed in here instead of hardcoded to 20
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
      Wayland.render(block, height: winH, width: winW)
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
