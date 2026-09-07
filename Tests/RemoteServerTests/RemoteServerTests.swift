import Chroma
import NIOCore
import NIOEmbedded
import RemoteProtocol
import Testing

@testable import RemoteServer

@MainActor
struct RemoteServerTests {
  private func reply(from channel: EmbeddedChannel) async throws -> RemoteMessage {
    for _ in 0..<500 {
      channel.embeddedEventLoop.run()
      if var bytes = try channel.readOutbound(as: ByteBuffer.self) {
        return try #require(try RemoteWire.decode(from: &bytes))
      }
      try await Task.sleep(for: .milliseconds(2))
    }
    throw MissingReply()
  }
  private struct MissingReply: Error {}

  @Test func creditsUnchangedFramesAndReconnect() async throws {
    let server = RemoteServer(content: EmptyBlock())
    let first = EmbeddedChannel()
    let second = EmbeddedChannel()
    try await first.connect(to: SocketAddress(ipAddress: "127.0.0.1", port: 9328)).get()
    try await second.connect(to: SocketAddress(ipAddress: "127.0.0.1", port: 9328)).get()
    defer {
      server.disconnected(first)
      server.disconnected(second)
      _ = try? first.finish()
      _ = try? second.finish()
      try? server.shutdown()
    }
    server.receive(.viewport(Size(width: 800, height: 600)), from: first)
    try await Task.sleep(for: .milliseconds(40))
    #expect(try first.readOutbound(as: ByteBuffer.self) == nil)
    server.receive(.requestFrame, from: first)
    guard case .frame = try await reply(from: first) else {
      Issue.record("First credit must produce a full frame")
      return
    }
    server.receive(.requestFrame, from: first)
    #expect(try await reply(from: first) == .frameUnchanged)
    try await Task.sleep(for: .milliseconds(40))
    #expect(try first.readOutbound(as: ByteBuffer.self) == nil)
    server.disconnected(first)
    server.receive(.requestFrame, from: second)
    guard case .frame = try await reply(from: second) else {
      Issue.record("New connection must receive a full frame")
      return
    }
  }
}
