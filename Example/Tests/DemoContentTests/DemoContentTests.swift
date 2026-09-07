import Chroma
import DemoContent
import HeadlessBackend
import RemoteProtocol
import Testing

@MainActor
struct DemoContentTests {
  @Test func sharedSceneSurvivesWireRoundTrip() throws {
    let demo = DemoApplication(itemCount: 100, shortcutModifier: .command)
    let renderer = HeadlessRenderer(size: demo.windowSize)
    renderer.content = demo.body
    let frame = renderer.render()
    #expect(!frame.commands.isEmpty)
    var bytes = try RemoteWire.encode(
      .frame(id: 1, inputSequence: 0, viewport: frame.viewport, commands: frame.commands))
    guard case .frame(_, _, let viewport, let commands) = try RemoteWire.decode(from: &bytes) else {
      Issue.record("Expected a complete demo frame")
      return
    }
    #expect(viewport == frame.viewport)
    #expect(commands == frame.commands)
    #expect(bytes.readableBytes == 0)
  }

  @Test func shortcutsUseDisplayPlatformRatherThanDaemonPlatform() {
    let apple = DemoApplication(shortcutModifier: .command)
    let linux = DemoApplication(shortcutModifier: .superKey)
    #expect(apple.keyBindings.command(for: KeyChord("c", modifiers: .command))! == .editing(.copy))
    #expect(linux.keyBindings.command(for: KeyChord("c", modifiers: .superKey))! == .editing(.copy))
    #expect(linux.keyBindings.command(for: KeyChord("c", modifiers: .command)) == nil)
    #expect(apple.editingKeyBindings.command(for: KeyChord("j"))! == .editing(.insert("j")))
  }
}
