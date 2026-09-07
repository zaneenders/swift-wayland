#if METAL_BACKEND

import AppKit
import Chroma
import Metal
import MetalBackend
import MetalKit
import NIOCore
import NIOPosix
import RemoteProtocol

@MainActor
public final class RemoteMetalClient: NSObject, MTKViewDelegate, NSWindowDelegate {
  private let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
  private var channel: Channel?
  private let queue: MTLCommandQueue
  private let displayRenderer: MetalDisplayListRenderer
  private let view: ChromaInputView
  private let window: NSWindow
  private var latestFrame: (viewport: Size, commands: [DrawCommand])?
  private var inputSequence: UInt64 = 0
  private var isShuttingDown = false
  private var statisticsStartedAt = ProcessInfo.processInfo.systemUptime
  private var statisticsFrames = 0
  private var statisticsBytes = 0
  private var statisticsCommands = 0
  private var statisticsDecodeTime: TimeInterval = 0
  private var statisticsRenderTime: TimeInterval = 0
  private var frameRequestTimer: Timer?
  private var frameRequestOutstanding = false
  private var requestedFramesPerSecond: Double = 30
  // AppKit window/delegate relationships are not owning. Keep the coordinator
  // alive for the duration of NSApplication.run(), even when its caller's local
  // variable is no longer considered live by the optimizer.
  private var lifetimeRetain: RemoteMetalClient?

  public init(size: Size = Size(width: 800, height: 600), title: String = "Chroma Remote") throws {
    guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
      throw BackendError.unavailable(backend: "Remote Metal", reason: "no compatible GPU was found")
    }
    self.queue = queue
    let frame = CGRect(x: 0, y: 0, width: CGFloat(size.width), height: CGFloat(size.height))
    let view = ChromaInputView(frame: frame, device: device)
    view.clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 1)
    view.isPaused = true
    view.enableSetNeedsDisplay = true
    self.view = view
    view.keyBindings = Self.remoteKeyBindings
    self.displayRenderer = try MetalDisplayListRenderer(device: device, pixelFormat: view.colorPixelFormat)
    self.window = NSWindow(
      contentRect: frame, styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered, defer: false)
    super.init()
    window.title = title
    window.contentView = view
    window.delegate = self
    window.center()
    view.delegate = self
    view.onInputAvailable = { [weak self] in self?.sendPendingInput() }
  }

  public func connect(
    host: String = "127.0.0.1", port: Int = 9328, framesPerSecond: Double = 30
  ) throws {
    requestedFramesPerSecond = framesPerSecond.isFinite ? max(1, framesPerSecond) : 30
    let channel = try ClientBootstrap(group: group)
      .channelOption(ChannelOptions.socketOption(.tcp_nodelay), value: 1)
      .channelInitializer { [weak self] channel in
        channel.pipeline.addHandler(
          RemoteClientHandler(
            onMessage: { [weak self] message, byteCount, decodeDuration in
              Task { @MainActor in
                self?.receive(message, byteCount: byteCount, decodeDuration: decodeDuration)
              }
            },
            onInactive: { [weak self] in
              Task { @MainActor in self?.connectionClosed() }
            }))
      }
      .connect(host: host, port: port).wait()
    self.channel = channel
    // Write directly here. Scheduling through eventLoop.execute allowed the
    // application run loop to start before the initial viewport was enqueued.
    let write = channel.writeAndFlush(try RemoteWire.encode(.viewport(currentViewport)))
    write.whenFailure { error in print("Initial viewport write failed: \(error)") }
    startFrameRequests()
  }

  private func startFrameRequests() {
    frameRequestTimer?.invalidate()
    let timer = Timer(timeInterval: 1 / requestedFramesPerSecond, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.requestFrameIfNeeded() }
    }
    RunLoop.main.add(timer, forMode: .common)
    frameRequestTimer = timer
    requestFrameIfNeeded()
  }

  private func requestFrameIfNeeded() {
    guard !frameRequestOutstanding else { return }
    frameRequestOutstanding = true
    send(.requestFrame)
  }

  public func run() {
    lifetimeRetain = self
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    window.makeKeyAndOrderFront(nil)
    window.makeFirstResponder(view)
    app.activate(ignoringOtherApps: true)
    app.run()
  }

  public func windowWillClose(_ notification: Notification) {
    shutdown()
    NSApplication.shared.terminate(nil)
  }

  public func windowDidResize(_ notification: Notification) {
    guard !isShuttingDown else { return }
    send(.viewport(currentViewport))
  }

  private func shutdown() {
    guard !isShuttingDown else { return }
    isShuttingDown = true

    // Stop AppKit callbacks before closing NIO. Window teardown can otherwise
    // produce resize/input callbacks that try to schedule work on the stopped group.
    frameRequestTimer?.invalidate()
    frameRequestTimer = nil
    view.onInputAvailable = nil
    view.delegate = nil
    window.delegate = nil

    let openChannel = channel
    channel = nil
    if let openChannel, openChannel.isActive {
      try? openChannel.close().wait()
    }
    try? group.syncShutdownGracefully()
    lifetimeRetain = nil
  }

  public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

  public func draw(in view: MTKView) {
    guard
      let frame = latestFrame,
      let drawable = view.currentDrawable,
      let descriptor = view.currentRenderPassDescriptor,
      let command = queue.makeCommandBuffer(),
      let encoder = command.makeRenderCommandEncoder(descriptor: descriptor)
    else { return }
    let renderStarted = ProcessInfo.processInfo.systemUptime
    displayRenderer.encode(
      DrawList(commands: frame.commands), viewport: frame.viewport,
      rasterScale: Point(
        x: Float(drawable.texture.width) / max(1, frame.viewport.width),
        y: Float(drawable.texture.height) / max(1, frame.viewport.height)),
      into: encoder)
    encoder.endEncoding()
    command.present(drawable)
    command.commit()
    displayRenderer.finishFrame()
    statisticsRenderTime += ProcessInfo.processInfo.systemUptime - renderStarted
  }

  private var currentViewport: Size {
    Size(width: Float(view.bounds.width), height: Float(view.bounds.height))
  }

  private static var remoteKeyBindings: KeyBindings {
    KeyBindings {
      Chroma.bind(.leftArrow, to: .navigation(.left))
      Chroma.bind(.rightArrow, to: .navigation(.right))
      Chroma.bind(.upArrow, to: .navigation(.up))
      Chroma.bind(.downArrow, to: .navigation(.down))
      Chroma.bind(.pageUp, to: .navigation(.pageUp))
      Chroma.bind(.pageDown, to: .navigation(.pageDown))
      Chroma.bind(.enter, to: .action(.activate))
      Chroma.bind(.space, to: .action(.activate))
      Chroma.bind(.backspace, to: .editing(.backspace))
      Chroma.bind(.delete, to: .editing(.deleteForward))
      Chroma.bind(.home, to: .editing(.moveCaretToStart))
      Chroma.bind(.end, to: .editing(.moveCaretToEnd))
      Chroma.bind(.escape, to: .editing(.endEditing))
    }
  }

  private func sendPendingInput() {
    guard !isShuttingDown else { return }
    inputSequence &+= 1
    send(.input(sequence: inputSequence, state: view.frameInput()))
  }

  private func send(_ message: RemoteMessage) {
    guard !isShuttingDown, let channel, channel.isActive else { return }
    do {
      let bytes = try RemoteWire.encode(message)
      // Channel.writeAndFlush is thread-safe and schedules on the channel's
      // event loop itself. Avoid an extra eventLoop.execute task that can be
      // left pending during shutdown.
      channel.writeAndFlush(bytes, promise: nil)
    } catch {
      print("Remote message encoding failed: \(error)")
    }
  }

  private func connectionClosed() {
    guard !isShuttingDown else { return }
    frameRequestTimer?.invalidate()
    frameRequestTimer = nil
    channel = nil
    window.title = "Chroma Remote Client — disconnected"
    print("Remote daemon disconnected")
  }

  private func receive(_ message: RemoteMessage, byteCount: Int, decodeDuration: TimeInterval) {
    guard !isShuttingDown else { return }
    guard case .frame(let id, _, let viewport, let commands) = message else { return }
    if latestFrame == nil {
      print("Received remote frame \(id) with \(commands.count) draw commands")
    }
    frameRequestOutstanding = false
    latestFrame = (viewport, commands)
    statisticsFrames += 1
    statisticsBytes += byteCount
    statisticsCommands += commands.count
    statisticsDecodeTime += decodeDuration
    printStatisticsIfNeeded()
    view.needsDisplay = true
  }

  private func printStatisticsIfNeeded() {
    let now = ProcessInfo.processInfo.systemUptime
    let elapsed = now - statisticsStartedAt
    guard elapsed >= 1 else { return }
    let frames = max(1, statisticsFrames)
    print(
      String(
        format: "client %.1f fps | %.2f Mbit/s | %.0f commands/frame | decode %.2f ms | encode GPU %.2f ms",
        Double(statisticsFrames) / elapsed, Double(statisticsBytes) * 8 / elapsed / 1_000_000,
        Double(statisticsCommands) / Double(frames),
        statisticsDecodeTime * 1_000 / Double(frames),
        statisticsRenderTime * 1_000 / Double(frames)))
    fflush(stdout)
    statisticsStartedAt = now
    statisticsFrames = 0
    statisticsBytes = 0
    statisticsCommands = 0
    statisticsDecodeTime = 0
    statisticsRenderTime = 0
  }
}

private final class RemoteClientHandler: ChannelInboundHandler, @unchecked Sendable {
  typealias InboundIn = ByteBuffer
  private var buffer = ByteBuffer()
  private let onMessage: @Sendable (RemoteMessage, Int, TimeInterval) -> Void
  private let onInactive: @Sendable () -> Void

  init(
    onMessage: @escaping @Sendable (RemoteMessage, Int, TimeInterval) -> Void,
    onInactive: @escaping @Sendable () -> Void
  ) {
    self.onMessage = onMessage
    self.onInactive = onInactive
  }

  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    var incoming = unwrapInboundIn(data)
    buffer.writeBuffer(&incoming)
    do {
      while true {
        let bytesBeforeDecode = buffer.readableBytes
        let started = ProcessInfo.processInfo.systemUptime
        guard let message = try RemoteWire.decode(from: &buffer) else { break }
        let duration = ProcessInfo.processInfo.systemUptime - started
        onMessage(message, bytesBeforeDecode - buffer.readableBytes, duration)
      }
      buffer.discardReadBytes()
    } catch {
      context.fireErrorCaught(error)
      context.close(promise: nil)
    }
  }

  func channelInactive(context: ChannelHandlerContext) {
    onInactive()
    context.fireChannelInactive()
  }

  func errorCaught(context: ChannelHandlerContext, error: Error) {
    print("Remote server error: \(error)")
    context.close(promise: nil)
  }
}

#endif
