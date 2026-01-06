import Logging
import Wayland

#if !Toolbar
@MainActor
func runDemo() async {
  let level: Logger.Level = .trace
  let frameLogger = Logger.create(logLevel: .warning, label: "Frame")
  let keyLogger = Logger.create(logLevel: level, label: "Key")
  var ips: [String] = []

  Wayland.setup()
  event_loop: for await ev in Wayland.events() {
    switch ev {
    case .frame(_, _):
      Wayland.preDraw()
      let screen = Screen(scale: 2, ips: ips, fps: String(format: "%.1f FPS", Wayland.currentFPS))
      Wayland.render(screen)
      Wayland.postDraw()
      if Wayland.elapsed > Wayland.refresh_rate {
        frameLogger.warning("\(Wayland.elapsed)")
      }
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
