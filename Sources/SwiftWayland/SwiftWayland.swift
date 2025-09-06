@main
struct SwiftWayland {
    static func main() async {
        Wayland.setupWayland()
        Wayland.startRenderLoop(word: "Scribe")
        Wayland.start()
    }
}
