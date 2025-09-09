@main
@MainActor
struct SwiftWayland {
    static func main() async {

        let state = AsyncState()
        Wayland.setup()
        event_loop: for await ev in Wayland.events() {
            switch ev {
            case .frame(let winH, let winW):
                var texts: [Text] = []
                var rects: [Rect] = []
                #if !Toolbar
                /*
                This is a mess well I figure out a more declaritive way of writing this code.
                It may be usefull to expose the current window height and wdith but I want layout
                logic to be more declaritive.
                */
                let snapShot = await state.view()
                let asciiStart = 32
                let asciiEnd = 126
                let code = asciiStart + (snapShot.tick % (asciiEnd - asciiStart + 1))
                let cmsg = UnicodeScalar(code).map { String(Character($0)) } ?? " "
                let words = ["Scribe", cmsg, "\(snapShot.count)"]

                let space = Float(Wayland.glyphSpacing) * Wayland.scale
                let textH = Float(Wayland.glyphH) * Wayland.scale
                let total = (Float(words.count) * (textH + space)) - space
                let startY = (Float(winH) - total) * 0.5
                for (i, word) in words.enumerated() {
                    let textW =
                        Float(word.count) * (Float(Wayland.glyphW + Wayland.glyphSpacing) * Wayland.scale) - space
                    let penX = (Float(winW) - textW) * 0.5
                    let penY = startY + (Float(i) * (textH + space))
                    let text = Text(word, at: (penX, penY), scale: Wayland.scale)
                    texts.append(text)
                }
                rects.append(
                    Rect(
                        dst_p0: (0, 0),
                        dst_p1: (Float(winW), 200),
                        color: Color(r: 0, g: 1, b: 1, a: 1)
                    ))
                rects.append(
                    Rect(
                        dst_p0: (Float(winW), Float(winH - 200)),
                        dst_p1: (0, Float(winH)),
                        color: Color(r: 0.5, g: 1, b: 0.5, a: 1)
                    ))
                #endif
                Wayland.drawFrame(texts, rects)
            case .key(let code, let keyState):
                if code == 1 {
                    Wayland.state = .exit
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
