import Foundation
import RemoteProtocol
import Testing

@testable import RemoteMetalClient

@Suite("Client clipboard failure replies")
struct ClipboardReplyEncoderTests {
  @Test(arguments: [0, 1, 1024])
  func oversizedPasteReturnsCorrelatedFailure(excess: Int) throws {
    let reply = ClipboardTransfer(
      id: 42, isReply: true,
      text: String(repeating: "x", count: RemoteWire.maximumClipboardBytes + excess))
    var result = try ClipboardReplyEncoder.encode(reply)
    #expect(result.notification?.contains("1 MiB") == true)
    #expect(
      try RemoteWire.decode(from: &result.bytes)
        == .clipboard(
          ClipboardTransfer(id: 42, isReply: true, success: false)))
    #expect(result.bytes.readableBytes == 0)
  }

  @Test func fullSizeValidPasteIsNotReplaced() throws {
    var reply = ClipboardTransfer(id: 42, isReply: true, text: "")
    let overhead = try JSONEncoder().encode(reply).count
    reply.text = String(repeating: "x", count: RemoteWire.maximumClipboardBytes - overhead)
    var result = try ClipboardReplyEncoder.encode(reply)
    #expect(result.notification == nil)
    #expect(try RemoteWire.decode(from: &result.bytes) == .clipboard(reply))
  }
}
