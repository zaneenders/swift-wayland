import Wayland

#if !Toolbar
@MainActor
func runLayout() async {

  Wayland.setup()
  var renderer = LayoutMachine(Wayland.self, .error)
  var block: some Block {
    LayoutTest()
  }

  event_loop: for await ev in Wayland.events() {
    switch ev {
    case .frame(let winH, let winW):
      var sizer = SizeWalker()
      block.walk(with: &sizer)
      var positioner = PositionWalker(sizes: sizer.sizes)
      block.walk(with: &positioner)
      var r = RenderWalker(positions: positioner.positions, Wayland.self)
      Wayland.preDraw()
      block.walk(with: &r)
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
