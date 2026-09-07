import Chroma
import Dispatch
import Foundation
import Logging
import NIOCore
import NIOPosix
import RemoteProtocol

@MainActor
public final class RemoteServer {
  private var logger = Logger(label: "chroma.remote.server")
  private let group: MultiThreadedEventLoopGroup
  private var serverChannel: Channel?
  private var clientChannel: Channel?
  private let interaction = Interaction()
  private var content: (any Block)?
  private var viewport: Size
  private var frameID: UInt64 = 0
  private var inputSequence: UInt64 = 0
  private var redrawScheduled = false
  private var statisticsStartedAt = ProcessInfo.processInfo.systemUptime
  private var statisticsFrames = 0
  private var statisticsBytes = 0
  private var statisticsCommands = 0
  private var statisticsDrawTime: TimeInterval = 0
  private var statisticsEncodeTime: TimeInterval = 0

  public init(content: any Block, size: Size = Size(width: 800, height: 600)) {
    self.content = content
    self.viewport = size
    self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    interaction.onRedrawRequested = { [weak self] in self?.scheduleRedraw() }
  }

  public func start(host: String = "127.0.0.1", port: Int = 9328) throws {
    // A ChannelHandler is stateful and may only belong to one channel. Construct
    // a new handler for every accepted connection so reconnecting after a probe
    // (`nc`) or a closed client does not cause NIO to reset the new connection.
    serverChannel = try ServerBootstrap(group: group)
      .serverChannelOption(ChannelOptions.backlog, value: 8)
      .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
      .childChannelOption(ChannelOptions.socketOption(.tcp_nodelay), value: 1)
      .childChannelInitializer { [weak self] channel in
        guard let self else { return channel.eventLoop.makeSucceededVoidFuture() }
        self.logger.debug("Accepted remote TCP connection")
        return channel.pipeline.addHandler(
          RemoteServerHandler(
            onMessage: { channel, message in
              Task { @MainActor [weak self] in self?.receive(message, from: channel) }
            },
            onInactive: { channel in
              Task { @MainActor [weak self] in
                if self?.clientChannel === channel { self?.clientChannel = nil }
              }
            },
            onError: { [logger = self.logger] error in
              logger.error("Remote channel failed", metadata: ["error": "\(error)"])
            }))
      }
      .bind(host: host, port: port).wait()
    logger.info("Chroma remote daemon listening", metadata: ["host": "\(host)", "port": "\(port)"])
  }

  /// Runs the executor used to evaluate the `@MainActor` block graph.
  /// Do not block on the NIO channel's close future: incoming messages are
  /// deliberately handed from NIO to the main actor.
  public func run() {
    #if os(macOS)
    RunLoop.main.run()
    #else
    // Foundation's main RunLoop is not a reliable process lifetime mechanism
    // on all Linux deployments. Dispatch keeps the daemon and main queue alive.
    dispatchMain()
    #endif
  }

  public func shutdown() throws {
    try clientChannel?.close().wait()
    try serverChannel?.close().wait()
    try group.syncShutdownGracefully()
  }

  private func receive(_ message: RemoteMessage, from channel: Channel) {
    if clientChannel == nil {
      logger.info("Remote client connected")
    }
    clientChannel = channel
    switch message {
    case .viewport(let size):
      viewport = size
      render()
    case .input(let sequence, let state):
      inputSequence = sequence
      render(input: state)
    case .requestFrame:
      render()
    case .frame:
      break
    }
  }

  private func scheduleRedraw() {
    guard !redrawScheduled else { return }
    redrawScheduled = true
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.redrawScheduled = false
      self.render()
    }
  }

  private func render(input: InputState = InputState()) {
    guard let channel = clientChannel else { return }
    let drawStarted = ProcessInfo.processInfo.systemUptime
    interaction.beginFrame(input: input)
    var drawList = DrawList()
    if let content {
      BlockEngine.draw(
        content, into: &drawList, in: Rect(origin: .zero, size: viewport),
        context: RenderContext(interaction: interaction))
    }
    interaction.endFrame()
    let drawDuration = ProcessInfo.processInfo.systemUptime - drawStarted
    frameID &+= 1
    do {
      let encodeStarted = ProcessInfo.processInfo.systemUptime
      let bytes = try RemoteWire.encode(
        .frame(id: frameID, inputSequence: inputSequence, viewport: viewport, commands: drawList.commands))
      let encodeDuration = ProcessInfo.processInfo.systemUptime - encodeStarted
      recordStatistics(
        byteCount: bytes.readableBytes, commandCount: drawList.commands.count,
        drawDuration: drawDuration, encodeDuration: encodeDuration)
      channel.writeAndFlush(bytes, promise: nil)
    } catch {
      logger.error("Remote frame encoding failed", metadata: ["error": "\(error)"])
    }
  }

  private func recordStatistics(
    byteCount: Int, commandCount: Int, drawDuration: TimeInterval, encodeDuration: TimeInterval
  ) {
    statisticsFrames += 1
    statisticsBytes += byteCount
    statisticsCommands += commandCount
    statisticsDrawTime += drawDuration
    statisticsEncodeTime += encodeDuration
    let now = ProcessInfo.processInfo.systemUptime
    let elapsed = now - statisticsStartedAt
    guard elapsed >= 1 else { return }
    let frames = max(1, statisticsFrames)
    let megabitsPerSecond = Double(statisticsBytes) * 8 / elapsed / 1_000_000
    logger.info(
      "Remote rendering statistics",
      metadata: [
        "fps": "\(String(format: "%.1f", Double(statisticsFrames) / elapsed))",
        "megabits_per_second": "\(String(format: "%.2f", megabitsPerSecond))",
        "commands_per_frame": "\(String(format: "%.0f", Double(statisticsCommands) / Double(frames)))",
        "draw_ms": "\(String(format: "%.2f", statisticsDrawTime * 1_000 / Double(frames)))",
        "encode_ms": "\(String(format: "%.2f", statisticsEncodeTime * 1_000 / Double(frames)))",
      ])
    statisticsStartedAt = now
    statisticsFrames = 0
    statisticsBytes = 0
    statisticsCommands = 0
    statisticsDrawTime = 0
    statisticsEncodeTime = 0
  }
}

private final class RemoteServerHandler: ChannelInboundHandler, @unchecked Sendable {
  typealias InboundIn = ByteBuffer
  private var buffer = ByteBuffer()
  private let onMessage: @Sendable (Channel, RemoteMessage) -> Void
  private let onInactive: @Sendable (Channel) -> Void
  private let onError: @Sendable (Error) -> Void

  init(
    onMessage: @escaping @Sendable (Channel, RemoteMessage) -> Void,
    onInactive: @escaping @Sendable (Channel) -> Void,
    onError: @escaping @Sendable (Error) -> Void
  ) {
    self.onMessage = onMessage
    self.onInactive = onInactive
    self.onError = onError
  }

  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    var incoming = unwrapInboundIn(data)
    buffer.writeBuffer(&incoming)
    do {
      while let message = try RemoteWire.decode(from: &buffer) {
        onMessage(context.channel, message)
      }
      buffer.discardReadBytes()
    } catch {
      context.fireErrorCaught(error)
      context.close(promise: nil)
    }
  }

  func channelInactive(context: ChannelHandlerContext) { onInactive(context.channel) }
  func errorCaught(context: ChannelHandlerContext, error: Error) {
    onError(error)
    context.close(promise: nil)
  }
}
