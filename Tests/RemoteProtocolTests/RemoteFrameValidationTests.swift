import Chroma
import Foundation
import RemoteProtocol
import Testing

struct RemoteFrameValidationTests {
  let viewport = Size(width: 800, height: 600)
  let rect = Rect(x: 0, y: 0, width: 40, height: 30)

  @Test func rejectsInvalidViewports() {
    for value: Float in [.nan, .infinity, -.infinity, -1, 0, .leastNonzeroMagnitude] {
      #expect(!RemoteFrameValidation.isValid(viewport: Size(width: value, height: 600), commands: []))
      #expect(!RemoteFrameValidation.isValid(viewport: Size(width: 800, height: value), commands: []))
    }
  }

  @Test func validatesEveryCommandAndClipBalance() throws {
    let image = try ImageResource(id: ImageID("test"), width: 1, height: 1, rgba8: Data([0, 0, 0, 255]))
    let bad: [DrawCommand] = [
      .fillRect(rect: Rect(x: .nan, y: 0, width: 1, height: 1), color: .white),
      .fillRect(
        rect: Rect(x: .greatestFiniteMagnitude, y: 0, width: .greatestFiniteMagnitude, height: 1), color: .white),
      .strokeRect(rect: rect, width: .infinity, color: .white),
      .fillRoundedRect(rect: rect, radii: CornerRadii(.nan), color: .white),
      .strokeRoundedRect(rect: rect, radii: .zero, width: -1, color: .white),
      .text(position: .zero, text: "x", color: .white, scale: .greatestFiniteMagnitude, face: .readable),
      .image(rect: Rect(x: .infinity, y: 0, width: 1, height: 1), image: image, scaling: .cover, alignment: .center),
      .pushClip(Rect(x: 0, y: 0, width: -1, height: 1)),
      .fillRect(rect: rect, color: Color(r: .nan, g: 0, b: 0, a: 1)),
    ]
    for command in bad {
      #expect(!RemoteFrameValidation.isValid(viewport: viewport, commands: [command]))
    }
    #expect(!RemoteFrameValidation.isValid(viewport: viewport, commands: [.popClip]))
    #expect(!RemoteFrameValidation.isValid(viewport: viewport, commands: [.pushClip(rect)]))
    #expect(
      RemoteFrameValidation.isValid(
        viewport: viewport,
        commands: [
          .pushClip(rect), .pushClip(.zero), .popClip,
          .fillRect(rect: Rect(x: -100, y: -100, width: 10, height: 10), color: .white),
          .image(rect: rect, image: image, scaling: .contain, alignment: .center), .popClip,
        ]))
  }

  @Test func rejectedPresentationStillDefinesImagesForNextFrame() throws {
    let sender = RemoteImageCache()
    let receiver = RemoteImageCache()
    let image = try ImageResource(id: ImageID("test"), width: 1, height: 1, rgba8: Data([0, 0, 0, 255]))
    let commands: [DrawCommand] = [.image(rect: rect, image: image, scaling: .contain, alignment: .center)]
    var bad = try RemoteWire.encode(
      .frame(
        id: 1, inputSequence: 0,
        viewport: Size(width: .infinity, height: 600), commands: commands), images: sender)
    guard case .frame(_, _, let size, let decoded) = try RemoteWire.decode(from: &bad, images: receiver) else {
      Issue.record("Expected frame")
      return
    }
    #expect(!RemoteFrameValidation.isValid(viewport: size, commands: decoded))
    let good = RemoteMessage.frame(id: 2, inputSequence: 0, viewport: viewport, commands: commands)
    var bytes = try RemoteWire.encode(good, images: sender)
    #expect(try RemoteWire.decode(from: &bytes, images: receiver) == good)
    #expect(sender.transmittedPixelBytes == 4)
  }
}
