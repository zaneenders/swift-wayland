import Logging
import Wayland

#if !Toolbar
@MainActor
func runLayout() async {

  let logger = Logger.create(logLevel: .trace)

  Wayland.setup()
  var block: some Block {
    LayoutTest()
  }

  event_loop: for await ev in Wayland.events() {
    switch ev {
    case .frame(let winH, let winW):
      Wayland.preDraw()
      var sizer = SizeWalker()
      block.walk(with: &sizer)
      var positioner = PositionWalker(sizes: sizer.sizes)
      block.walk(with: &positioner)
      var renderer = RenderWalker(positions: positioner.positions, Wayland.self)
      block.walk(with: &renderer)
      Wayland.postDraw()
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
