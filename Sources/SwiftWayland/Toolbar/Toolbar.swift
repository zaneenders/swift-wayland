#if Toolbar
import Foundation
import Wayland

struct SystemClock: Block {
  var time: String
  var layer: some Block {
    // TODO display to the right side of the screen
    Word(time).scale(2)
      .background(.black)
      .forground(.teal)
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
      let today = formatter.string(from: Date())
      let block = SystemClock(time: today)
      Wayland.draw(block)
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
