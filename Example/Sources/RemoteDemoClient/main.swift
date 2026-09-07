#if METAL_BACKEND
import Chroma
import RemoteMetalClient

@main
struct RemoteDemoClient {
  @MainActor
  static func main() throws {
    let client = try RemoteMetalClient(
      size: Size(width: 800, height: 520), title: "Chroma Remote Client")
    try client.connect()
    client.run()
  }
}
#else
#error("The remote demo client currently requires macOS and Metal.")
#endif
