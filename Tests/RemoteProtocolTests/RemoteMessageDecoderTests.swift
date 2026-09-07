import NIOCore
import NIOEmbedded
import RemoteProtocol
import Testing

struct RemoteMessageDecoderTests {
  @Test func fragmentedAndCoalescedMessages() throws {
    let channel = EmbeddedChannel(handler: ByteToMessageHandler(RemoteMessageDecoder()))
    defer { _ = try? channel.finish() }
    var bytes = try RemoteWire.encode(.requestFrame)
    var second = try RemoteWire.encode(.frameUnchanged)
    bytes.writeBuffer(&second)
    try channel.writeInbound(bytes.readSlice(length: 5)!)
    #expect(try channel.readInbound(as: DecodedRemoteMessage.self) == nil)
    try channel.writeInbound(bytes)
    let first = try #require(try channel.readInbound(as: DecodedRemoteMessage.self))
    #expect(first.message == .requestFrame)
    #expect(first.byteCount == 12)
    #expect(first.duration >= 0)
    #expect(try channel.readInbound(as: DecodedRemoteMessage.self)?.message == .frameUnchanged)
    #expect(try channel.readInbound(as: DecodedRemoteMessage.self) == nil)
  }

  @Test func malformedHeaderPropagatesError() throws {
    let channel = EmbeddedChannel(handler: ByteToMessageHandler(RemoteMessageDecoder()))
    defer { _ = try? channel.finish() }
    var bytes = try RemoteWire.encode(.requestFrame)
    bytes.setInteger(UInt32(0), at: 0)
    #expect(throws: RemoteProtocolError.invalidMagic) { try channel.writeInbound(bytes) }
  }
}
