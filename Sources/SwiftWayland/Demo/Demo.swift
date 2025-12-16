import Wayland

#if !Toolbar
@MainActor
func runDemo() async {
  let screen = Screen(o: .vertical)
  let state = AsyncState()

  Wayland.setup()
  var texts: [Text] = []
  var rects: [Rect] = []
  event_loop: for await ev in Wayland.events() {
    switch ev {
    case .frame(let winH, let winW):
      let snapShot = await state.view()
      let asciiStart = 32
      let asciiEnd = 126
      let code = asciiStart + (snapShot.tick % (asciiEnd - asciiStart + 1))
      let cmsg = UnicodeScalar(code).map { String(Character($0)) } ?? " "
      let words = ["Scribe", cmsg, "\(snapShot.count)"]

      let space = Wayland.glyphSpacing * Wayland.scale
      let textH = Wayland.glyphH * Wayland.scale
      let total = (UInt(words.count) * (textH + space)) - space
      let startY = (UInt(winH) - total) / 2
      for (i, word) in words.enumerated() {
        let textW =
          UInt(word.count) * (UInt(Wayland.glyphW + Wayland.glyphSpacing) * Wayland.scale) - space
        let penX = (winW - textW) / 2
        let penY = startY + (UInt(i) * (textH + space))
        let text = Text(word, at: (penX, penY), scale: Wayland.scale)
        texts.append(text)
      }
      rects.append(
        Rect(
          dst_p0: (0, 0),
          dst_p1: (winW, 200),
          color: Color.teal
        ))
      rects.append(
        Rect(
          dst_p0: (winW, winH - 200),
          dst_p1: (0, winH),
          color: Color.green
        ))
      Wayland.drawFrame((height: winH, width: winW), screen)
      //Wayland.drawFrame((height: winH, width: winW), texts, rects)
      texts = []
      rects = []
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
