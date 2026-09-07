import Chroma
import Dispatch
import Foundation
import Logging
import NIOCore
import NIOPosix
import RemoteProtocol

@MainActor
public final class RemoteServer {
  public var keyBindings = KeyBindings()
  public var editingKeyBindings = KeyBindings()
  private var pointerPosition = Point.zero
  private var clipboardEpoch: UInt64 = 0
  private struct EditorSnapshot {
    let text: String?
    let selection: Range<Int>?
    let leaf: WidgetID?
  }
  private struct PendingClipboard {
    enum Operation { case copy, cut, paste }
    let id: UInt64
    let epoch: UInt64
    let operation: Operation
    let snapshot: EditorSnapshot
  }
  private var pendingClipboard: PendingClipboard?
  private var deferredInput: [RemoteMessage] = []
  private var logger = Logger(label: "chroma.remote.server")
  private let group: MultiThreadedEventLoopGroup
  private let connectionFactory: RemoteServerConnectionFactory
  private var serverChannel: Channel?
  fileprivate var clientChannel: Channel?
  private let interaction = Interaction()
  private var content: (any Block)?
  private var viewport: Size
  private var frameID: UInt64 = 0
  private var statistics = ServerStatistics()
  private var inputSequence: UInt64 = 0
  private var redrawScheduled = false
  private var framesPerSecond: Double = 30
  private var lastProducedAt: TimeInterval = 0
  private var requestPending = false
  private var lastSentCommands: [DrawCommand]?
  private var lastSentViewport: Size?
  private var connectionEpoch: UInt64 = 0
  private let wireEncoder = ConnectionFrameEncoder()
  // Remains occupied across disconnects until old encoding/writing completes.
  private var frameInFlight = false
  private let encodingQueue = DispatchQueue(label: "chroma.remote.frame-encoding")
  private struct FrameSnapshot: Sendable {
    let message: RemoteMessage
    let channel: Channel
    let drawDuration: TimeInterval
    let commandCount: Int
  }

  public init(content: any Block, size: Size = Size(width: 800, height: 600)) {
    self.content = content
    self.viewport = size
    self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    self.connectionFactory = RemoteServerConnectionFactory()
    interaction.onRedrawRequested = { [weak self] in self?.scheduleRedraw() }
  }

  public func start(host: String = "127.0.0.1", port: Int = 9328) throws {
    // A ChannelHandler is stateful and may only belong to one channel. Construct
    // a new handler for every accepted connection so reconnecting after a probe
    // (`nc`) or a closed client does not cause NIO to reset the new connection.
    // Keep NIO's initializer in a nonisolated object. A closure literal created
    // here inherits @MainActor, while NIO invokes it on its event-loop thread.
    connectionFactory.server = self
    serverChannel = try ServerBootstrap(group: group)
      .serverChannelOption(ChannelOptions.backlog, value: 8)
      .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
      .childChannelInitializer(connectionFactory.initialize)
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
    let client = clientChannel
    clientChannel = nil
    connectionEpoch &+= 1
    try client?.close().wait()
    try serverChannel?.close().wait()
    try group.syncShutdownGracefully()
  }

  func receive(_ message: RemoteMessage, from channel: Channel) {
    if clientChannel == nil {
      logger.info("Remote client connected")
    }
    // The prototype has one interaction graph: reject competing clients rather
    // than allowing one connection to mutate another's pending clipboard edit.
    if let active = clientChannel, active !== channel {
      channel.close(promise: nil)
      return
    }
    clientChannel = channel
    if case .clipboard(let reply) = message {
      guard reply.isReply, let pending = pendingClipboard, pending.id == reply.id else { return }
      if reply.success {
        if pending.operation == .paste, let text = reply.text,
          pending.snapshot.leaf == interaction.editingLeaf,
          pending.snapshot.text == interaction.editingText,
          pending.snapshot.selection == interaction.textSelectionRange
        {
          render(input: InputState(textEvents: [.insert(text)]))
        }
        if pending.operation == .cut,
          pending.snapshot.text == interaction.editingText,
          pending.snapshot.selection == interaction.textSelectionRange,
          pending.snapshot.leaf == interaction.editingLeaf
        {
          render(input: InputState(textEvents: [.deleteForward]))
        }
      }
      finishClipboard()
      return
    }
    if pendingClipboard != nil {
      switch message {
      case .input, .key:
        guard deferredInput.count < 4096 else {
          channel.close(promise: nil)
          return
        }
        deferredInput.append(message)
        return
      default: break
      }
    }
    switch message {
    case .clipboard: break
    case .key(let sequence, let event):
      guard sequence > inputSequence else { return }
      inputSequence = sequence
      let map = interaction.isTextEditing ? keyBindings.overlay(editingKeyBindings) : keyBindings
      if let chord = event.chord, let resolution = map.command(for: chord) {
        if let command = resolution { execute(command) }
      } else if interaction.isTextEditing, let text = event.text {
        render(input: InputState(textEvents: [.insert(text)]))
      }
    case .viewport(let size):
      viewport = size
      render()
    case .input(let sequence, let state):
      guard sequence > inputSequence else { return }
      pointerPosition = state.pointerPosition
      inputSequence = sequence
      render(input: state)
    case .frameRate(let fps):
      framesPerSecond = Double(fps)
    case .requestFrame:
      requestPending = true
      scheduleRedraw()
    case .frame, .frameUnchanged:
      break
    }
  }

  private func execute(_ command: Command) {
    guard case .editing(let event) = command else {
      render(input: InputState(commands: [command]))
      return
    }
    switch event {
    case .copy, .cut, .paste:
      let text: String?
      if event == .paste {
        guard interaction.isTextEditing else { return }
        text = nil
      } else {
        text = event == .cut ? interaction.editableSelectionText() : interaction.copyText()
        // RemoteWire.encode below enforces the actual JSON payload size,
        // including escaping and metadata, rather than a worst-case text limit.
        guard let text, !text.isEmpty else { return }
      }
      let id = inputSequence
      clipboardEpoch &+= 1
      let epoch = clipboardEpoch
      pendingClipboard = PendingClipboard(
        id: id, epoch: epoch,
        operation: event == .cut ? .cut : (event == .paste ? .paste : .copy),
        snapshot: EditorSnapshot(
          text: interaction.editingText,
          selection: interaction.textSelectionRange, leaf: interaction.editingLeaf))
      do {
        let bytes = try RemoteWire.encode(.clipboard(ClipboardTransfer(id: id, text: text)))
        clientChannel?.writeAndFlush(bytes, promise: nil)
      } catch {
        finishClipboard()
        return
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
        guard let self, self.pendingClipboard?.id == id, self.pendingClipboard?.epoch == epoch else { return }
        self.finishClipboard()
      }
    case .selectAll where !interaction.isTextEditing:
      interaction.selectAll(at: pointerPosition)
      render()
    default:
      render(input: InputState(textEvents: [event]))
    }
  }

  private func finishClipboard() {
    pendingClipboard = nil
    while pendingClipboard == nil, !deferredInput.isEmpty, let channel = clientChannel {
      let next = deferredInput.removeFirst()
      receive(next, from: channel)
    }
  }

  func disconnected(_ channel: Channel) {
    guard clientChannel === channel else { return }
    clientChannel = nil
    pendingClipboard = nil
    clipboardEpoch &+= 1
    deferredInput.removeAll()
    inputSequence = 0
    connectionEpoch &+= 1
    redrawScheduled = false
    requestPending = false
    lastSentCommands = nil
    lastSentViewport = nil
    lastProducedAt = 0
    framesPerSecond = 30
  }

  private func scheduleRedraw() {
    guard clientChannel != nil, !redrawScheduled else { return }
    redrawScheduled = true
    let epoch = connectionEpoch
    let delay = max(0, lastProducedAt + 1 / framesPerSecond - ProcessInfo.processInfo.systemUptime)
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
      guard let self, self.connectionEpoch == epoch else { return }
      self.redrawScheduled = false
      // A request is a single presentation credit. Input can update the graph
      // immediately, but neither input nor animation can bypass this credit.
      guard self.requestPending, !self.frameInFlight else { return }
      self.lastProducedAt = ProcessInfo.processInfo.systemUptime
      if let snapshot = self.render() { self.publishFrame(snapshot) }
    }
  }

  private func publishFrame(_ snapshot: FrameSnapshot) {
    requestPending = false
    if case .frame(_, _, let viewport, let commands) = snapshot.message {
      if lastSentViewport == viewport, lastSentCommands == commands {
        if let bytes = try? RemoteWire.encode(.frameUnchanged) {
          snapshot.channel.writeAndFlush(bytes, promise: nil)
        }
        return
      }
      lastSentViewport = viewport
      lastSentCommands = commands
    }
    frameInFlight = true
    encodeFrame(snapshot)
  }

  @discardableResult
  private func render(input: InputState = InputState()) -> FrameSnapshot? {
    guard let channel = clientChannel else { return nil }
    let drawStarted = ProcessInfo.processInfo.systemUptime
    interaction.beginFrame(input: input)
    var drawList = DrawList()
    if let content {
      BlockEngine.draw(
        content, into: &drawList, in: Rect(origin: .zero, size: viewport),
        context: RenderContext(interaction: interaction))
    }
    interaction.endFrame()
    // Clear the coalescing flag after every frame. If drawing requested another
    // frame it has already scheduled a render through onRedrawRequested; leaving
    // the flag set would suppress every later invalidation.
    _ = interaction.consumeRedrawRequest()
    drawList = drawList.culled(to: viewport)
    let drawDuration = ProcessInfo.processInfo.systemUptime - drawStarted
    frameID &+= 1
    let snapshot = FrameSnapshot(
      message: .frame(id: frameID, inputSequence: inputSequence, viewport: viewport, commands: drawList.commands),
      channel: channel, drawDuration: drawDuration, commandCount: drawList.commands.count)
    return snapshot
  }

  private func encodeFrame(_ snapshot: FrameSnapshot) {
    // The graph and interaction remain main-actor isolated. Only its immutable,
    // Sendable display list crosses to this worker; input never waits on encoding.
    let wireEncoder = self.wireEncoder
    encodingQueue.async { [weak self] in
      let started = ProcessInfo.processInfo.systemUptime
      let result = Result { try wireEncoder.encode(snapshot.message, channel: snapshot.channel) }
      let duration = ProcessInfo.processInfo.systemUptime - started
      DispatchQueue.main.async { [weak self] in
        self?.encodedFrame(snapshot, result: result, duration: duration)
      }
    }
  }

  private func encodedFrame(
    _ snapshot: FrameSnapshot, result: Result<EncodedFrame, Error>, duration: TimeInterval
  ) {
    // Never deliver work from an old connection to a newly connected client.
    guard clientChannel === snapshot.channel, snapshot.channel.isActive else {
      completeFrame()
      return
    }
    switch result {
    case .success(let encoded):
      let bytes = encoded.bytes
      statistics.imageBytes += encoded.imageBytes
      statistics.record(
        byteCount: bytes.readableBytes, commandCount: snapshot.commandCount,
        drawDuration: snapshot.drawDuration, encodeDuration: duration)
      // Keep the slot occupied until NIO drains this write. Otherwise a slow
      // connection would accumulate encoded frames even with bounded encoding.
      snapshot.channel.writeAndFlush(bytes).whenComplete { [weak self] result in
        DispatchQueue.main.async {
          if case .failure(let error) = result {
            self?.logger.error("Remote frame write failed", metadata: ["error": "\(error)"])
            snapshot.channel.close(promise: nil)
          }
          self?.completeFrame()
        }
      }
    case .failure(let error):
      logger.error("Remote frame encoding failed", metadata: ["error": "\(error)"])
      snapshot.channel.close(promise: nil)
      completeFrame()
    }
  }

  private func completeFrame() {
    frameInFlight = false
    if requestPending { scheduleRedraw() }
  }
}

private final class RemoteServerConnectionFactory: @unchecked Sendable {
  private static let logger = Logger(label: "chroma.remote.server.connection")
  weak var server: RemoteServer?

  func initialize(channel: Channel) -> EventLoopFuture<Void> {
    Self.logger.info("Accepted remote TCP connection")
    return channel.eventLoop.makeCompletedFuture {
      try channel.pipeline.syncOperations.addHandlers(
        ByteToMessageHandler(RemoteMessageDecoder()),
        RemoteServerHandler(
          onMessage: { [weak self] channel, message in
            DispatchQueue.main.async { self?.server?.receive(message, from: channel) }
          },
          onInactive: { [weak self] channel in
            DispatchQueue.main.async {
              self?.server?.disconnected(channel)
            }
          },
          onError: { error in
            Self.logger.error("Remote channel failed", metadata: ["error": "\(error)"])
          }))
    }
  }
}

private final class RemoteServerHandler: ChannelInboundHandler, @unchecked Sendable {
  typealias InboundIn = DecodedRemoteMessage
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
    let decoded = unwrapInboundIn(data)
    onMessage(context.channel, decoded.message)
  }

  func channelInactive(context: ChannelHandlerContext) { onInactive(context.channel) }
  func errorCaught(context: ChannelHandlerContext, error: Error) {
    onError(error)
    context.close(promise: nil)
  }
}

// Only accessed by the serial encoding queue. Reset resources on reconnect;
// encoding happens only after a presentation credit is consumed.
private final class ConnectionFrameEncoder: @unchecked Sendable {
  private var channel: Channel?
  private var images = RemoteImageCache()
  func encode(_ message: RemoteMessage, channel: Channel) throws -> EncodedFrame {
    if self.channel !== channel {
      self.channel = channel
      images = RemoteImageCache()
    }
    let before = images.transmittedPixelBytes
    let bytes = try RemoteWire.encode(message, images: images)
    return EncodedFrame(bytes: bytes, imageBytes: images.transmittedPixelBytes - before)
  }
}

private struct EncodedFrame: Sendable {
  let bytes: ByteBuffer
  let imageBytes: Int
}
