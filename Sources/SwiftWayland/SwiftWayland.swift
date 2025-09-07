@main
@MainActor
struct SwiftWayland {
    static func main() async {
        let state = AsyncState()
        Wayland.setup()
        event_loop: for await ev in WaylandEvents.events() {
            let count = await state.getCount()
            switch ev {
            case .frame:
                Wayland.drawFrame("Scribe", count: count)
            case .key(let code, let state):
                if code == 1 {
                    Wayland.state = .exit
                }
                print("Key:", code, state)
            }
        }

        // Read why the final state
        switch Wayland.state {
        case .error(let reason):
            print("error: \(reason)")
        case .running, .exit:
            ()
        }
    }
}

actor AsyncState {
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
                self.count += 1
            }
        }
    }

    func getCount() -> Int {
        return count
    }
}
