import Foundation
import NIOCore
import NIOPosix

@main
struct SwiftWayland {

    let wayland_display_object_id: UInt32 = 1
    var wayland_current_object_id: UInt32 = 1
    var frame_buffer_fd: Int32!

    var height: Int = 800
    var width: Int = 600

    public static func main() async {
        var wayland = Self()
        await wayland.connect()
    }
}

extension SwiftWayland {

    mutating func connect() async {
        do {
            guard let path = ProcessInfo.processInfo.environment["XDG_RUNTIME_DIR"] else {
                print("Environment varable XDG_RUNTIME_DIR not found.")
                throw WaylandSetupError.xdg_runtime_dir
            }
            var display = "wayland-0"
            if let _display = ProcessInfo.processInfo.environment["WAYLAND_DISPLAY"] {
                display = _display
            }
            let wayland_socket_path = "\(path)/\(display)"
            print("Connecting to: \(wayland_socket_path)")
            let addr = try SocketAddress(unixDomainSocketPath: wayland_socket_path)

            let bootstrap = try await ClientBootstrap(group: .singletonMultiThreadedEventLoopGroup)
                .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
                .connect(to: addr) { channel in
                    channel.eventLoop.makeCompletedFuture {
                        try channel.pipeline.syncOperations.addHandler(ByteToMessageHandler(WaylandMessageCoder()))
                        try channel.pipeline.syncOperations.addHandler(MessageToByteHandler(WaylandMessageCoder()))
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
                self.wayland_current_object_id = try await onConnect(outbound)
                self.frame_buffer_fd = setupFrameBuffer()
                // FIXME: there is an `unsafe` call here but the swift-format is merging it with `message`
                for try await message in inbound {
                    handleWaylandResponse(message)
                }
            }
            print("Goodbye")
        } catch {
            print(error)
        }
    }

    private func handleWaylandResponse(_ message: WaylandMessage) {
        if message.object == self.wayland_display_object_id
            && message.opcode == WaylandOpCodes.wayland_wl_display_error_event.value
        {
            print("wl_display: Error")
        } else if message.object == self.wayland_current_object_id
            && message.opcode == WaylandOpCodes.registry_event_global.value
        {
            guard var buffer = message.message,
                let name = buffer.readInteger(endianness: .little, as: UInt32.self),
                let interface_length = buffer.readInteger(endianness: .little, as: UInt32.self),
                let msg = buffer.readString(length: Int(interface_length)),
                let verison = buffer.readInteger(endianness: .little, as: UInt32.self)
            else {
                print("wl_registry:: Invalid event")
                return
            }
            print("wl_registry:", message.object, message.opcode, message.length, name, msg, verison)
            // TODO: You left off here.
        }
    }

    private func onConnect(_ outbound: NIOAsyncChannelOutboundWriter<WaylandMessage>) async throws -> UInt32 {
        var contents = ByteBuffer()
        contents.writeInteger(wayland_current_object_id + 1, endianness: .little, as: UInt32.self)
        let message = WaylandMessage(
            object: wayland_display_object_id,
            length: UInt16(8 + contents.readableBytes),
            opcode: WaylandOpCodes.get_registry.value,
            message: contents)
        try await outbound.write(message)
        return self.wayland_current_object_id + 1
    }

    private func setupFrameBuffer() -> FD {
        let shared_name = UUID().uuidString
        let shared_fd = unsafe shm_open(shared_name, O_RDWR | O_EXCL | O_CREAT, 0600)
        unsafe shm_unlink(shared_name)
        let pixels = height * width * 4
        ftruncate(shared_fd, pixels)
        mmap(nil, pixels, PROT_READ | PROT_WRITE, MAP_SHARED, shared_fd, 0)
        return shared_fd
    }
}

typealias FD = Int32
