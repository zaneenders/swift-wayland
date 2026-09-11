import Chroma
import DemoContent
import RemoteServer

/// Shared configuration for manually launched and launcher-owned demo servers.
public enum DemoBackend {
  @MainActor
  public static func makeServer(for demo: DemoApplication) -> RemoteServer {
    let server = RemoteServer(content: demo.body, size: demo.windowSize)
    server.frameObserver = demo.frameObserver
    server.keyBindings = demo.keyBindings.overlay {
      bind(.enter, to: .action(.activate))
    }
    server.editingKeyBindings = demo.editingKeyBindings
    return server
  }
}
