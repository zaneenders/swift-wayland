import CEGL
import CGLES3
import CWaylandClient
import CWaylandEGL
import CXDGShell
import Foundation

@main
struct SwiftWayland {
    public static func main() {
        Wayland.setupWayland()

        var start = ContinuousClock.now
        var end = ContinuousClock.now

        while Wayland.running && wl_display_dispatch(Wayland.display) != -1 {
            Wayland.drawFrame()
            end = ContinuousClock.now
            print(end - start)
            start = ContinuousClock.now
        }
    }
}
