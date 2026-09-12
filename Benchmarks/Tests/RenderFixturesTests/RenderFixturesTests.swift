import Chroma
import RemoteProtocol
import RenderFixtures
import Testing

@Test(arguments: RenderFixture.names)
func deterministicReplay(scene: String) throws {
  let fixture = try RenderFixture(name: scene, count: 256)
  #expect(fixture.list.commands == (try RenderFixture(name: scene, count: 256)).list.commands)
  var sender = RemoteImageCache()
  var receiver = RemoteImageCache()
  var sizes: [Int] = []
  for frame in 0..<(fixture.sequence.count * 2 + 1) {
    let message = RemoteMessage.frame(
      id: UInt64(frame), inputSequence: 0,
      viewport: fixture.viewport, commands: fixture.sequence[frame % fixture.sequence.count].commands)
    var wire = try RemoteWire.encode(message, images: &sender)
    sizes.append(wire.readableBytes)
    #expect(try RemoteWire.decode(from: &wire, images: &receiver) == message)
    #expect(wire.readableBytes == 0)
  }
  if fixture.sequence.count == 1 { #expect(sizes[1] == sizes[2]) }
  if scene == "images" { #expect(sizes[0] > sizes[1]) }
  let culled = fixture.list.culled(to: fixture.viewport)
  #expect(culled.commands == culled.culled(to: fixture.viewport).commands)
  if scene == "clipped" { #expect(culled.commands.count < fixture.list.commands.count) }
}

@Test(arguments: TranscriptReplay.names)
func transcriptSequencesAreDeterministicAndBounded(scene: String) throws {
  let fixture = try RenderFixture(name: scene, count: 10_000)
  let repeated = try RenderFixture(name: scene, count: 10_000)
  #expect(fixture.sequence.count == 60)
  #expect(fixture.sequence.map(\.commands) == repeated.sequence.map(\.commands))
  #expect(fixture.sequence.allSatisfy { $0.commands.count < 400 })
  #expect(fixture.sequence.first!.commands != fixture.sequence.last!.commands)
  for list in fixture.sequence {
    var depth = 0
    for command in list.commands {
      switch command {
      case .pushClip: depth += 1
      case .popClip: depth -= 1
      default: break
      }
      #expect(depth >= 0)
    }
    #expect(depth == 0)
  }
}
