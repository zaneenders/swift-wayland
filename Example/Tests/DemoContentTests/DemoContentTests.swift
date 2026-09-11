import Chroma
import DemoContent
import Foundation
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
    for key: Key in [
      .character("j"), .character("f"), .character("d"), .character("k"),
      .character("l"), .character("s"), .space, .pageUp, .pageDown,
    ] {
      #expect(apple.keyBindings.command(for: KeyChord(key)) == nil)
      #expect(linux.keyBindings.command(for: KeyChord(key)) == nil)
    }
  }
}

@MainActor
@Test func captureShortcutRequestsExactlyOneFrame() throws {
  let directory = try captureTestDirectory()
  defer { try? FileManager.default.removeItem(at: directory) }
  let configuration = try DemoCaptureConfiguration(directory: directory)
  let demo = DemoApplication(itemCount: 100, shortcutModifier: .command, captureConfiguration: configuration)
  #expect(demo.keyBindings.command(for: KeyChord("g", modifiers: [.control, .shift]))! == .application("demo.capture"))
  let renderer = HeadlessRenderer(size: demo.windowSize)
  renderer.content = demo.body
  renderer.render()
  let requested = renderer.render(input: InputState(commands: [.application("demo.capture")]))
  #expect(
    requested.commands.contains { command in
      if case .text(_, let text, _, _, _) = command { return text == "Scene capture requested" }
      return false
    })
}

@MainActor
@Test func demoCaptureWritesReplayableScene() async throws {
  let directory = try captureTestDirectory()
  defer { try? FileManager.default.removeItem(at: directory) }
  let configuration = try DemoCaptureConfiguration(directory: directory)
  let demo = DemoApplication(itemCount: 100, shortcutModifier: .command, captureConfiguration: configuration)
  let renderer = HeadlessRenderer(size: demo.windowSize)
  renderer.content = demo.body
  renderer.frameObserver = demo.frameObserver
  renderer.render()
  let captured = renderer.render(input: InputState(commands: [.application("demo.capture")]))
  // Poll only in the test; the production demo uses its existing refresh cadence.
  for _ in 0..<200 {
    try await Task.sleep(for: .milliseconds(25))
    let frame = renderer.render()
    for command in frame.commands {
      if case .text(_, let text, _, _, _) = command, text.hasPrefix("Saved scene: ") {
        let filename = String(text.dropFirst("Saved scene: ".count))
        let url = directory.appendingPathComponent(filename)
        defer { try? FileManager.default.removeItem(at: url) }
        let decoded = try SceneCapture.decode(Data(contentsOf: url))
        #expect(decoded.drawList.commands == captured.commands)
        #expect(decoded.viewport == captured.viewport)
        return
      }
    }
  }
  Issue.record("Capture did not complete within five seconds")
}

private func captureTestDirectory() throws -> URL {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
  return directory
}

@MainActor
@Test func captureIsDisabledWithoutConfiguration() {
  let demo = DemoApplication()
  #expect(demo.frameObserver == nil)
  #expect(demo.keyBindings.command(for: KeyChord("g", modifiers: [.control, .shift])) == nil)
  let renderer = HeadlessRenderer(size: demo.windowSize)
  renderer.content = demo.body
  let frame = renderer.render(input: InputState(commands: [.application("demo.capture")]))
  #expect(
    !frame.commands.contains { command in
      if case .text(_, let text, _, _, _) = command { return text.contains("capture") }
      return false
    })
}

@Test func captureConfigurationRequiresExplicitValidDirectory() throws {
  var empty: [String] = []
  #expect(try DemoCaptureConfiguration.parse(arguments: &empty) == nil)
  for invalid in [
    ["--capture-directory"], ["--capture-directory", ""],
    ["--capture-directory", "/tmp", "--capture-directory", "/tmp"], ["--capture"],
  ] {
    var arguments = invalid
    #expect(throws: (any Error).self) { try DemoCaptureConfiguration.parse(arguments: &arguments) }
  }
  let directory = try captureTestDirectory()
  defer { try? FileManager.default.removeItem(at: directory) }
  var arguments = ["localhost", "--capture-directory", directory.path, "9328"]
  let configuration = try DemoCaptureConfiguration.parse(arguments: &arguments)
  #expect(configuration?.directory == directory.standardizedFileURL.resolvingSymlinksInPath())
  #expect(arguments == ["localhost", "9328"])
  #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
  let file = directory.appendingPathComponent("not-directory")
  try Data().write(to: file)
  #expect(throws: (any Error).self) { try DemoCaptureConfiguration(directory: file) }
  #expect(throws: (any Error).self) {
    try DemoCaptureConfiguration(directory: directory.appendingPathComponent("missing"))
  }
  #expect(throws: (any Error).self) { try DemoCaptureConfiguration(directory: URL(string: "https://example.com")!) }
}

@Test func nativeCaptureDefaultUsesDemoPackageDirectory() throws {
  let expected = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .standardizedFileURL.resolvingSymlinksInPath()
  let configuration = try DemoCaptureConfiguration.nativeDefault()
  #expect(configuration.directory.path == expected.path)
  #expect(
    FileManager.default.fileExists(
      atPath: configuration.directory.appendingPathComponent("Package.swift").path))
}
