import Logging
import Wayland

#if !Toolbar
@MainActor
func runLayout() async {
  Wayland.setup()
  let block = Test2()
  Wayland.setup()
  var renderer = LayoutMachine(Wayland.self, .error)
  event_loop: for await ev in Wayland.events() {
    switch ev {
    case .frame(let winH, let winW):
      Wayland.preDraw()
      block.walk(with: &renderer)
      Wayland.postDraw()
      renderer.reset()
    case .key(let code, let keyState):
      switch (code, keyState) {
      case (1, _):
        Wayland.exit()
      default:
        ()
      }
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
