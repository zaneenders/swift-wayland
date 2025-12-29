import Logging
import Wayland

#if !Toolbar
@MainActor
func runLayout() async {

  let logger = Logger.create(logLevel: .trace)

  var block: some Block {
    LayoutTest()
  }

  Wayland.setup()
  event_loop: for await ev in Wayland.events() {
    switch ev {
    case .frame(let winH, let winW):
      Wayland.draw(block)
      logger.trace("\(Wayland.elapsed)")
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
