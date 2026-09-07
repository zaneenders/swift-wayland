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

  public func connect(host: String = "127.0.0.1", port: Int = 9328) throws {
    let channel = try ClientBootstrap(group: group)
      .channelInitializer { channel in
        channel.pipeline.addHandler(
          RemoteClientHandler { [weak self] message in
            Task { @MainActor in self?.receive(message) }
          })
      }
      .connect(host: host, port: port).wait()
    self.channel = channel
    // Write directly here. Scheduling through eventLoop.execute allowed the
    // application run loop to start before the initial viewport was enqueued.
    let write = channel.writeAndFlush(try RemoteWire.encode(.viewport(currentViewport)))
    write.whenFailure { error in print("Initial viewport write failed: \(error)") }
  }

  public func run() {
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
    view.onInputAvailable = nil
    view.delegate = nil
    window.delegate = nil

    let openChannel = channel
    channel = nil
    if let openChannel, openChannel.isActive {
      try? openChannel.close().wait()
    }
    try? group.syncShutdownGracefully()
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

  private func receive(_ message: RemoteMessage) {
    guard !isShuttingDown else { return }
    guard case .frame(let id, _, let viewport, let commands) = message else { return }
    if latestFrame == nil {
      print("Received remote frame \(id) with \(commands.count) draw commands")
    }
    latestFrame = (viewport, commands)
    view.needsDisplay = true
  }
}

private final class RemoteClientHandler: ChannelInboundHandler, @unchecked Sendable {
  typealias InboundIn = ByteBuffer
  private var buffer = ByteBuffer()
  private let onMessage: @Sendable (RemoteMessage) -> Void

  init(onMessage: @escaping @Sendable (RemoteMessage) -> Void) { self.onMessage = onMessage }

  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    var incoming = unwrapInboundIn(data)
    buffer.writeBuffer(&incoming)
    do {
      while let message = try RemoteWire.decode(from: &buffer) { onMessage(message) }
      buffer.discardReadBytes()
    } catch {
      context.fireErrorCaught(error)
      context.close(promise: nil)
    }
  }

  func errorCaught(context: ChannelHandlerContext, error: Error) {
    print("Remote server error: \(error)")
    context.close(promise: nil)
  }
}

#endif
