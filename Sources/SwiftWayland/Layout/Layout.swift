import Wayland

#if !Toolbar
@MainActor
func runLayout() async {

  Wayland.setup()
  var renderer = LayoutMachine(Wayland.self, .error)
  var block: some Block {
    LayoutTest()
  }

  var sizer = SizeWalker()
  block.walk(with: &sizer)

  event_loop: for await ev in Wayland.events() {
    switch ev {
    case .frame(let winH, let winW):
      Wayland.preDraw()
      block.draw(&renderer)
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
