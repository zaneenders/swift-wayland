import Wayland

#if !Toolbar
@MainActor
func runDemo() async {
  var ips: [String] = []

  Wayland.setup()
  event_loop: for await ev in Wayland.events() {
    switch ev {
    case .frame(let winH, let winW):
      let screen = Screen(o: .vertical, ips: ips)
      Wayland.drawFrame((height: winH, width: winW), screen)
    case .key(let code, let keyState):
      if code == 1 {
        Wayland.exit()
      }
      if keyState == 1 {
        print("key: \(code)")
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
    print("error: \(reason)")
  case .running, .exit:
    ()
  }
}

#endif
