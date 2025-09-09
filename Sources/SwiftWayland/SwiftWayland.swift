@main
@MainActor
struct SwiftWayland {
    static func main() async {

        let state = AsyncState()
        Wayland.setup()
        event_loop: for await ev in WaylandEvents.events() {
            switch ev {
            case .frame:
                let snapShot = await state.view()
                let asciiStart = 32
                let asciiEnd = 126
                let code = asciiStart + (snapShot.tick % (asciiEnd - asciiStart + 1))
                let cmsg = UnicodeScalar(code).map { String(Character($0)) } ?? " "
                Wayland.drawFrame(["Scribe", cmsg, "\(snapShot.count)"])
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
