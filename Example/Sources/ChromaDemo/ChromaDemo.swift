import Chroma
import DemoContent

#if METAL_BACKEND
import MetalBackend
#elseif WAYLAND_BACKEND
import WaylandBackend
#endif

#if METAL_BACKEND
private protocol DemoApp: MetalApp {}
#elseif WAYLAND_BACKEND
private protocol DemoApp: WaylandApp {}
#else
private protocol DemoApp: App {}

extension DemoApp {
  @MainActor
  static func main() throws {
    throw BackendError.unavailable(
      backend: "ChromaDemo",
      reason: "no graphical backend is enabled"
    )
  }
}
#endif

@main
struct ChromaDemo: DemoApp {
  private let demo = DemoApplication()
  var title: String { demo.title }
  var windowSize: Size { demo.windowSize }
  var minimumRefreshRate: Double { demo.minimumRefreshRate }
  var keyBindings: KeyBindings { demo.keyBindings }
  var body: some Block { demo.body }
}
