import Foundation
import Logging
import NIOCore
import NIOPosix

@main
enum WaylandClient {
    public static func main() async {
        await connect()
    }
}

// MARK: connect
extension WaylandClient {
    private static func connect() async {
        let logger = {
            var _logger = Logger(label: "connect")
            _logger.logLevel = .trace
            return _logger
        }()

        do {
            guard let path = ProcessInfo.processInfo.environment["XDG_RUNTIME_DIR"] else {
                logger.error("Environment varable XDG_RUNTIME_DIR not found.")
                throw WaylandSetupError.xdg_runtime_dir
            }
            var display = "wayland-0"
            if let _display = ProcessInfo.processInfo.environment["WAYLAND_DISPLAY"] {
                display = _display
            }
            let wayland_socket_path = "\(path)/\(display)"
            logger.notice("Connecting to: \(wayland_socket_path)")
            let addr = try SocketAddress(unixDomainSocketPath: wayland_socket_path)

            let bootstrap = try await ClientBootstrap(group: .singletonMultiThreadedEventLoopGroup)
                .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
                .connect(to: addr) { channel in
                    channel.eventLoop.makeCompletedFuture {
                        try channel.pipeline.syncOperations.addHandler(ByteToMessageHandler(WaylandMessageDecoder()))
                        try channel.pipeline.syncOperations.addHandler(WaylandMessageEncoder())
                        return try NIOAsyncChannel(
                            wrappingChannelSynchronously: channel,
                            configuration: NIOAsyncChannel.Configuration(
                                inboundType: WaylandMessage.self,
                                outboundType: WaylandMessage.self
                            )
                        )
                    }
                }

            try await bootstrap.executeThenClose {
                inbound,
                outbound in
                var session = WaylandClientSession(outbound)
                try await session.setupPhase()
                // FIXME: there is an `unsafe` call here but the swift-format is merging it with `message`
                for try await message in inbound {
                    try await session.handle(message: message)
                }
                logger.notice("Close")
            }
            logger.notice("Goodbye")
        } catch {
            logger.critical("\(error)")
        }
    }
}
