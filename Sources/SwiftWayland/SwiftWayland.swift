@main
@MainActor
struct SwiftWayland {
    static func main() async {
        #if Toolbar
        await runToolbar()
        #else
        await runDemo()
        #endif
    }
}
