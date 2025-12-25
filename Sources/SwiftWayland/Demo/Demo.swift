import Logging
import Wayland

#if !Toolbar
@MainActor
func runDemo() async {
  let level: Logger.Level = .trace
  let frameLogger = Logger.create(logLevel: .warning, label: "Frame")
  let keyLogger = Logger.create(logLevel: level, label: "Key")
  var ips: [String] = []

  var block: some Block {
    Screen(o: .vertical, ips: ips)
    //Test2()
  }

  Wayland.setup()
  var renderer = LayoutMachine(Wayland.self, .error)
  event_loop: for await ev in Wayland.events() {
    switch ev {
    case .frame(let winH, let winW):
      Wayland.preDraw()
      block.walk(with: &renderer)
      Wayland.postDraw()
      if Wayland.elapsed > Duration(.milliseconds(16)) {
        frameLogger.warning("\(Wayland.elapsed)")
      }
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
        block.moveIn(&renderer)
      case (31, 1):  // S
        block.moveOut(&renderer)
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
