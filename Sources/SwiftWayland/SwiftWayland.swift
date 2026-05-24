import Wayland

@main
@MainActor
struct SwiftWayland {
  static func main() async {
    // Use --toolbar flag to run in toolbar mode.
    if CommandLine.arguments.contains("--toolbar") {
      Wayland.mode = .toolbar
      await runToolbar()
    } else {
      Wayland.mode = .windowed
      await runDemo()
    }
  }
}
