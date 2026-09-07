import Chroma
import NIOCore
import RemoteProtocol
import Testing

@Suite("Remote keys and clipboard")
struct ClipboardProtocolTests {
  @Test func portableKeysAndClipboardRoundTripInOrder() throws {
    let messages: [RemoteMessage] = [
      .key(sequence: 1, event: RemoteKeyEvent(chord: KeyChord("a", modifiers: .command))),
      .key(sequence: 2, event: RemoteKeyEvent(chord: KeyChord(.leftArrow))),
      .key(sequence: 3, event: RemoteKeyEvent(chord: nil, text: "café 👩🏽‍💻")),
      .clipboard(ClipboardTransfer(id: 3)),
      .clipboard(ClipboardTransfer(id: 3, isReply: true, text: "Hello\n世界")),
      .clipboard(ClipboardTransfer(id: 4, text: "Copy me")),
      .clipboard(ClipboardTransfer(id: 4, isReply: true, success: false)),
    ]
    var wire = ByteBuffer()
    for message in messages {
      var encoded = try RemoteWire.encode(message)
      wire.writeBuffer(&encoded)
    }
    var partial = ByteBuffer()
    var received: [RemoteMessage] = []
    while let byte: UInt8 = wire.readInteger() {
      partial.writeInteger(byte)
      while let message = try RemoteWire.decode(from: &partial) { received.append(message) }
    }
    #expect(received == messages)
  }

  @Test func clipboardPayloadIsBounded() {
    #expect(throws: RemoteProtocolError.self) {
      _ = try RemoteWire.encode(
        .clipboard(
          ClipboardTransfer(
            id: 1,
            text: String(repeating: "x", count: RemoteWire.maximumClipboardBytes))))
    }
  }

  @Test func appBindingsCanOverrideAndDisable() {
    let base = KeyBindings { bind("q", to: .editing(.copy)) }
    let editing = base.overlay {
      bind("q", to: .editing(.paste))
      disable("a", modifiers: .command)
    }
    #expect(base.command(for: KeyChord("q"))! == .editing(.copy))
    #expect(editing.command(for: KeyChord("q"))! == .editing(.paste))
    #expect(editing.command(for: KeyChord("a", modifiers: .command))! == nil)
    #expect(editing.command(for: KeyChord("v", modifiers: .command)) == nil)
  }
}
