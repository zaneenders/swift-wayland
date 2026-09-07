import Chroma
import Foundation
import NIOCore
import NIOPosix
import RemoteProtocol

@MainActor
public final class RemoteServer {
  private let group: MultiThreadedEventLoopGroup
  private var serverChannel: Channel?
  private var clientChannel: Channel?
  private let interaction = Interaction()
  private var content: (any Block)?
  private var viewport: Size
  private var frameID: UInt64 = 0
  private var inputSequence: UInt64 = 0
  private var redrawScheduled = false

  public init(content: any Block, size: Size = Size(width: 800, height: 600)) {
    self.content = content
    self.viewport = size
    self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    interaction.onRedrawRequested = { [weak self] in self?.scheduleRedraw() }
  }

  public func start(host: String = "127.0.0.1", port: Int = 9328) throws {
    let handler = RemoteServerHandler { [weak self] channel, message in
      Task { @MainActor in self?.receive(message, from: channel) }
    } onInactive: { [weak self] channel in
      Task { @MainActor in
        if self?.clientChannel === channel { self?.clientChannel = nil }
      }
    }
    serverChannel = try ServerBootstrap(group: group)
      .serverChannelOption(ChannelOptions.backlog, value: 8)
      .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
      .childChannelInitializer { channel in channel.pipeline.addHandler(handler) }
      .bind(host: host, port: port).wait()
    print("Chroma remote daemon listening on \(host):\(port)")
    FileHandle.standardOutput.synchronizeFile()
  }

  /// Runs the main event loop used to evaluate the `@MainActor` block graph.
  /// Do not block the main thread on the NIO channel's close future: incoming
  /// messages are deliberately handed from NIO to the main actor.
  public func run() {
    RunLoop.main.run()
  }

  public func shutdown() throws {
    try clientChannel?.close().wait()
    try serverChannel?.close().wait()
    try group.syncShutdownGracefully()
  }

  private func receive(_ message: RemoteMessage, from channel: Channel) {
    if clientChannel == nil {
      print("Remote client connected")
      FileHandle.standardOutput.synchronizeFile()
    }
    clientChannel = channel
    switch message {
    case .viewport(let size):
      viewport = size
      render()
    case .input(let sequence, let state):
      inputSequence = sequence
      render(input: state)
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
    interaction.beginFrame(input: input)
    var drawList = DrawList()
    if let content {
      BlockEngine.draw(
        content, into: &drawList, in: Rect(origin: .zero, size: viewport),
        context: RenderContext(interaction: interaction))
    }
    interaction.endFrame()
    frameID &+= 1
    do {
      let bytes = try RemoteWire.encode(
        .frame(id: frameID, inputSequence: inputSequence, viewport: viewport, commands: drawList.commands))
      channel.eventLoop.execute { channel.writeAndFlush(bytes, promise: nil) }
    } catch {
      print("Remote frame encoding failed: \(error)")
    }
  }
}

private final class RemoteServerHandler: ChannelInboundHandler, @unchecked Sendable {
  typealias InboundIn = ByteBuffer
  private var buffer = ByteBuffer()
  private let onMessage: @Sendable (Channel, RemoteMessage) -> Void
  private let onInactive: @Sendable (Channel) -> Void

  init(
    onMessage: @escaping @Sendable (Channel, RemoteMessage) -> Void,
    onInactive: @escaping @Sendable (Channel) -> Void
  ) {
    self.onMessage = onMessage
    self.onInactive = onInactive
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
    print("Remote client error: \(error)")
    context.close(promise: nil)
  }
}
