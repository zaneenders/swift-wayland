import Chroma
import Foundation
import RemoteServer

@main
struct RemoteDemoDaemon {
  @MainActor
  static func main() throws {
    let arguments = Array(CommandLine.arguments.dropFirst())
    if arguments.contains("--help") || arguments.contains("-h") {
      print("usage: RemoteDemoDaemon [bind-host] [port]")
      print("example: RemoteDemoDaemon 0.0.0.0 9328")
      return
    }
    let host = arguments.first ?? "127.0.0.1"
    let port = arguments.dropFirst().first.flatMap(Int.init) ?? 9328

    let state = DemoState()
    let server = RemoteServer(content: DemoView(state: state), size: Size(width: 800, height: 520))
    try server.start(host: host, port: port)
    server.run()
  }
}

@MainActor
private final class DemoState {
  var count = 0
}

private struct DemoView: Block {
  let state: DemoState

  var body: some Block {
    VStack(spacing: 18) {
      Spacer()
      Text("CHROMA REMOTE")
        .fontScale(1.2)
        .foregroundColor(.yellow)
      Text("The block graph is running in the daemon.")
        .fontScale(0.75)
      Text("The client GPU renders this DrawList.")
        .fontScale(0.75)
      Text("Remote button count: \(state.count)")
        .fontScale(0.9)
      HStack(spacing: 12) {
        Spacer()
        Button("Decrease", id: WidgetID("decrease")) { state.count -= 1 }
          .sizing(x: .fixed(160))
        Button("Increase", id: WidgetID("increase")) { state.count += 1 }
          .sizing(x: .fixed(160))
        Spacer()
      }
      .sizing(y: .fixed(54))
      Spacer()
    }
    .padding(30)
    .background(Color(r: 0.06, g: 0.07, b: 0.12, a: 1))
  }
}
