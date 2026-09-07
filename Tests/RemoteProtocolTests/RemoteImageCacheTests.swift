import Chroma
import Foundation
import NIOCore
import RemoteProtocol
import Testing

struct RemoteImageCacheTests {
  private func frame(_ images: [ImageResource]) -> RemoteMessage {
    .frame(
      id: 1, inputSequence: 0, viewport: Size(width: 100, height: 100),
      commands: images.map {
        .image(
          rect: Rect(x: 0, y: 0, width: 20, height: 20), image: $0,
          scaling: .contain, alignment: .center)
      })
  }
  private func image(_ id: String = "image", generation: UInt64 = 0) throws -> ImageResource {
    try ImageResource(
      id: ImageID(id), generation: generation, width: 16, height: 16,
      rgba8: Data(repeating: UInt8(generation % 256), count: 1024))
  }

  @Test func unchangedPixelsAreSentOnceAndGenerationsAreRedefined() throws {
    let sender = RemoteImageCache()
    let receiver = RemoteImageCache()
    let original = try image()
    for resource in [original, original, try image(generation: 1), original] {
      let message = frame([resource, resource])
      var bytes = try RemoteWire.encode(message, images: sender)
      #expect(try RemoteWire.decode(from: &bytes, images: receiver) == message)
    }
    #expect(sender.transmittedPixelBytes == 3072)
    #expect(receiver.transmittedPixelBytes == sender.transmittedPixelBytes)
    let compact = try RemoteWire.encode(frame([original]), images: sender)
    let fresh = try RemoteWire.encode(frame([original]), images: RemoteImageCache())
    #expect(fresh.readableBytes - compact.readableBytes == 1036)
    var missingResource = compact
    #expect(throws: RemoteProtocolError.malformedMessage) {
      try RemoteWire.decode(from: &missingResource, images: RemoteImageCache())
    }
  }

  @Test func evictionIsDeterministicAndEvictedResourcesAreResent() throws {
    let sender = RemoteImageCache()
    let receiver = RemoteImageCache()
    for id in (0..<130).map(String.init) + ["0"] {
      let message = frame([try image(id)])
      var bytes = try RemoteWire.encode(message, images: sender)
      #expect(try RemoteWire.decode(from: &bytes, images: receiver) == message)
    }
    #expect(sender.transmittedPixelBytes == 131 * 1024)
  }

  @Test func fragmentedDefinitionsDoNotMutateCacheAndFailureRollsBack() throws {
    let sender = RemoteImageCache()
    let receiver = RemoteImageCache()
    let message = frame([try image()])
    let bytes = try RemoteWire.encode(message, images: sender)
    var prefix = try #require(bytes.getSlice(at: 0, length: bytes.readableBytes - 1))
    #expect(try RemoteWire.decode(from: &prefix, images: receiver) == nil)
    #expect(receiver.transmittedPixelBytes == 0)
    var malformed = bytes
    malformed.setInteger(UInt32(bytes.readableBytes - 12 + 1), at: 8, endianness: .little)
    malformed.writeInteger(UInt8(0))
    #expect(throws: RemoteProtocolError.malformedMessage) {
      try RemoteWire.decode(from: &malformed, images: receiver)
    }
    #expect(receiver.transmittedPixelBytes == 0)
    var complete = bytes
    #expect(try RemoteWire.decode(from: &complete, images: receiver) == message)
  }

  @Test func pacingMessagesRoundTripAndRejectInvalidRates() throws {
    for message in [RemoteMessage.frameRate(30), .frameUnchanged] {
      var bytes = try RemoteWire.encode(message)
      #expect(try RemoteWire.decode(from: &bytes) == message)
    }
    for rate: Float in [0, -1, .infinity, .nan, 241] {
      #expect(throws: RemoteProtocolError.malformedMessage) {
        try RemoteWire.encode(.frameRate(rate))
      }
    }
  }
}
