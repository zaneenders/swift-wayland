import Chroma
import Foundation
import RemoteProtocol
import Testing

@Test func sceneCaptureIsSelfContainedAndPreservesScale() throws {
  var list = DrawList()
  let image = try ImageResource(id: ImageID("capture"), width: 1, height: 1, rgba8: Data([1, 2, 3, 255]))
  list.pushClip(Rect(x: 0, y: 0, width: 40, height: 30))
  list.text("capture", at: .zero, color: .white)
  list.image(image, in: Rect(x: 0, y: 0, width: 10, height: 10))
  list.popClip()
  let frame = FrameObservation(drawList: list, viewport: Size(width: 40, height: 30), rasterScale: Point(x: 2, y: 2))
  let data = try SceneCapture.encode(frame)
  for _ in 0..<2 {
    let decoded = try SceneCapture.decode(data)
    #expect(decoded.drawList.commands == frame.drawList.commands)
    #expect(decoded.viewport == frame.viewport)
    #expect(decoded.rasterScale == frame.rasterScale)
  }
  #expect(throws: (any Error).self) { try SceneCapture.decode(Data(data.dropLast())) }
  #expect(throws: (any Error).self) { try SceneCapture.decode(data + Data([0])) }
  #expect(throws: (any Error).self) { try SceneCapture.decode(Data("not a capture".utf8)) }
}
