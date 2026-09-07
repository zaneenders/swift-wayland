#if METAL_BACKEND
import Chroma
import Foundation
import RemoteMetalClient

@main
struct RemoteDemoClient {
  @MainActor
  static func main() throws {
    let arguments = Array(CommandLine.arguments.dropFirst())
    if arguments.contains("--help") || arguments.contains("-h") {
      print("usage: RemoteDemoClient [host] [port]")
      print("example: RemoteDemoClient 192.168.1.42 9328")
      return
    }
    let host = arguments.first ?? "127.0.0.1"
    let port = arguments.dropFirst().first.flatMap(Int.init) ?? 9328

    let client = try RemoteMetalClient(
      size: Size(width: 800, height: 520), title: "Chroma Remote Client — \(host)")
    print("Connecting to \(host):\(port)")
    try client.connect(host: host, port: port)
    client.run()
  }
}
#else
#error("The remote demo client currently requires macOS and Metal.")
#endif
