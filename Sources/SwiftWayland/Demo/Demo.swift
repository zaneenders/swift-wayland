import Wayland

#if !Toolbar
@MainActor
func runDemo() async {
  let screen = Screen(o: .vertical)
  let state = AsyncState()

  Wayland.setup()
  event_loop: for await ev in Wayland.events() {
    switch ev {
    case .frame(let winH, let winW):
      Wayland.drawFrame((height: winH, width: winW), screen)
    case .key(let code, let keyState):
      if code == 1 {
        Wayland.exit()
      }
      if keyState == 1 {
        await state.bump()
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

struct SnapShot {
  let tick: Int
  let count: Int
}

actor AsyncState {
  var tick = 0
  var count = 0

  init() {
    Task {
      await start()
    }
  }

  func start() {
    Task {
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(0.5))
        self.tick += 1
      }
    }
  }

  func bump() {
    count += 1
  }

  func view() -> SnapShot {
    SnapShot(tick: tick, count: count)
  }
}
#endif
