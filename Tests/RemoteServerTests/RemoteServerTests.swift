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

@MainActor private final class PointerRecorder {
  var inputs: [InputState] = []
}

private struct PointerRecordingBlock: PrimitiveBlock {
  let recorder: PointerRecorder
  @MainActor func sizeThatFits(_ proposal: Size, context: RenderContext) -> Size { proposal }
  @MainActor func draw(into list: inout DrawList, in rect: Rect, context: RenderContext) {
    recorder.inputs.append(context.interaction.input)
  }
}

extension RemoteServerTests {
  @Test func presentationAndKeyboardPreservePointerWithoutReplayingEdges() async throws {
    let recorder = PointerRecorder()
    let server = RemoteServer(content: PointerRecordingBlock(recorder: recorder))
    let channel = EmbeddedChannel()
    try await channel.connect(to: SocketAddress(ipAddress: "127.0.0.1", port: 9328)).get()
    defer {
      server.disconnected(channel)
      _ = try? channel.finish()
      try? server.shutdown()
    }
    let position = Point(x: 100, y: 120)
    let origin = Point(x: 90, y: 110)
    server.receive(
      .input(
        sequence: 1,
        state: InputState(
          pointerPosition: position, pointerPressPosition: origin, pointerDown: true,
          pointerPressed: true, scrollDelta: Point(x: 0, y: 3))), from: channel)
    #expect(recorder.inputs.last?.pointerPressed == true)
    server.receive(.requestFrame, from: channel)
    _ = try await reply(from: channel)
    let presented = try #require(recorder.inputs.last)
    #expect(presented.pointerPosition == position)
    #expect(presented.pointerPressPosition == origin)
    #expect(presented.pointerDown)
    #expect(!presented.pointerPressed && !presented.pointerReleased)
    #expect(presented.scrollDelta == .zero)
    server.keyBindings = KeyBindings { bind("j", to: .navigation(.down)) }
    server.receive(.key(sequence: 2, event: RemoteKeyEvent(chord: KeyChord("j"))), from: channel)
    #expect(recorder.inputs.last?.pointerPosition == position)
    #expect(recorder.inputs.last?.pointerDown == true)
    server.receive(.viewport(Size(width: 400, height: 300)), from: channel)
    #expect(recorder.inputs.last?.pointerPosition == position)
    #expect(recorder.inputs.last?.commands.isEmpty == true)
    server.receive(
      .input(
        sequence: 3,
        state: InputState(
          pointerPosition: position, pointerPressPosition: origin, pointerReleased: true)), from: channel)
    server.receive(.requestFrame, from: channel)
    _ = try await reply(from: channel)
    #expect(recorder.inputs.last?.pointerDown == false)
    #expect(recorder.inputs.last?.pointerReleased == false)
  }
}
