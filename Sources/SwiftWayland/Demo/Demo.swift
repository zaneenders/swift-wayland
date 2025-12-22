import Logging
import Wayland

#if !Toolbar
@MainActor
func runDemo() async {
  let level: Logger.Level = .trace
  let frameLogger = Logger.create(logLevel: .error, label: "Frame")
  let keyLogger = Logger.create(logLevel: level, label: "Frame")
  var ips: [String] = []

  Wayland.setup()
  var renderer = LayoutMachine(Wayland.self, .error)
  event_loop: for await ev in Wayland.events() {
    switch ev {
    case .frame(let winH, let winW):
      let screen = Screen(o: .vertical, ips: ips)
      Wayland.preDraw()
      screen.draw(&renderer)
      Wayland.postDraw()
      frameLogger.trace("\(Wayland.elapsed)")
      renderer.reset()
    case .key(let code, let keyState):
      if keyState == 1 {
        keyLogger.trace("key: \(code)")
      }
      switch (code, keyState) {
      case (1, _):
        Wayland.exit()
      case (36, 1):  // J
        ()
      case (33, 1):  // F
        ()
      case (37, 1):  // K
        ()
      case (32, 1):  // D
        ()
      case (38, 1):  // L
        let screen = Screen(o: .vertical, ips: ips)
        screen.moveIn(&renderer)
      case (31, 1):  // S
        let screen = Screen(o: .vertical, ips: ips)
        screen.moveOut(&renderer)
      case (_, 1):
        ips = ["Loading..."]
        Task {
          let r = await getIps()
          ips = r
        }
      default:
        ()
      }
    }
  }

  // Read the final state
  switch Wayland.state {
  case .error(let reason):
    keyLogger.error("error: \(reason)")
  case .running, .exit:
    ()
  }
}

#endif
