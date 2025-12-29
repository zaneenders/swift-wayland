import Logging
import Wayland

#if !Toolbar
@MainActor
func runDemo() async {
  let level: Logger.Level = .trace
  let frameLogger = Logger.create(logLevel: .error, label: "Frame")
  let keyLogger = Logger.create(logLevel: level, label: "Key")
  var ips: [String] = []

  Wayland.setup()
  event_loop: for await ev in Wayland.events() {
    switch ev {
    case .frame(let winH, let winW):
      let screen = Screen(ips: ips)
      Wayland.draw(screen)
      frameLogger.trace("\(Wayland.elapsed)")
    case .key(let code, let keyState):
      if keyState == 1 {
        keyLogger.trace("key: \(code)")
      }
      switch (code, keyState) {
      case (1, _):
        Wayland.exit()
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
