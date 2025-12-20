import Logging
import Wayland

#if !Toolbar
@MainActor
func runDemo() async {
  let level: Logger.Level = .trace
  let logger = Logger.create(logLevel: level)
  var ips: [String] = []

  Wayland.setup()
  var renderer = LayoutMachine(Wayland.self, level)
  event_loop: for await ev in Wayland.events() {
    switch ev {
    case .frame(let winH, let winW):
      let screen = Screen(o: .vertical, ips: ips)
      Wayland.preDraw()
      screen.draw(&renderer)
      Wayland.postDraw()
      logger.trace("\(Wayland.elapsed)")
      renderer.reset()
    case .key(let code, let keyState):
      if code == 1 {
        Wayland.exit()
      }
      if keyState == 1 {
        logger.trace("key: \(code)")
        ips = ["Loading..."]
        Task {
          let r = await getIps()
          ips = r
        }
      }
    }
  }

  // Read the final state
  switch Wayland.state {
  case .error(let reason):
    logger.error("error: \(reason)")
  case .running, .exit:
    ()
  }
}

#endif
