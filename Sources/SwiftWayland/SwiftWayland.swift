@main
struct SwiftWayland {
    static func main() async {
        Wayland.setupWayland()

        while Wayland.stillRunning {
            Wayland.drawFrame(word: "Scribe")
        }
    }
}
