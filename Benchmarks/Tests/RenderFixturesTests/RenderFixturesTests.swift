import Chroma
import RemoteProtocol
import RenderFixtures
import Testing

@Test(arguments: RenderFixture.names)
func deterministicReplay(scene: String) throws {
  let fixture = try RenderFixture(name: scene, count: 256)
  #expect(fixture.list.commands == (try RenderFixture(name: scene, count: 256)).list.commands)
  let sender = RemoteImageCache()
  let receiver = RemoteImageCache()
  var sizes: [Int] = []
  for frame in 0..<3 {
    let message = RemoteMessage.frame(
      id: UInt64(frame), inputSequence: 0,
      viewport: fixture.viewport, commands: fixture.list.commands)
    var wire = try RemoteWire.encode(message, images: sender)
    sizes.append(wire.readableBytes)
    #expect(try RemoteWire.decode(from: &wire, images: receiver) == message)
    #expect(wire.readableBytes == 0)
  }
  #expect(sizes[1] == sizes[2])
  if scene == "images" { #expect(sizes[0] > sizes[1]) }
  let culled = fixture.list.culled(to: fixture.viewport)
  #expect(culled.commands == culled.culled(to: fixture.viewport).commands)
  if scene == "clipped" { #expect(culled.commands.count < fixture.list.commands.count) }
}
