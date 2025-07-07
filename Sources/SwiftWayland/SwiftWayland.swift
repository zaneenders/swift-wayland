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
                    await handleWaylandResponse(message, outbound)
                }
                print("Close")
            }
            print("Goodbye")
        } catch {
            print(error)
        }
    }

    private mutating func handleWaylandResponse(
        _ message: WaylandMessage,
        _ outbound: NIOAsyncChannelOutboundWriter<WaylandMessage>
    ) async {
        if message.object == self.wayland_display_object_id
            && message.opcode == WaylandOpCodes.wayland_wl_display_error_event.value
        {
            print("wl_display: Error", message.length)
            if let error_message = message.message {
                print(error_message.getString(at: 0, length: Int(message.length - 8)))
            }
        } else if message.object == 2  // wl_registry
            && message.opcode == WaylandOpCodes.registry_event_global.value
        {
            guard var buffer = message.message,
                let name = buffer.readInteger(endianness: .little, as: UInt32.self),
                let interface_length = buffer.readInteger(endianness: .little, as: UInt32.self),
                let _interface_name = buffer.readString(length: roundup4(Int(interface_length))),
                let verison = buffer.readInteger(endianness: .little, as: UInt32.self)
            else {
                print("wl_registry:: Invalid event")
                return
            }
            // Trim trailing null byte padding
            let end_index = _interface_name.firstIndex(of: "\0") ?? _interface_name.endIndex
            let interface_name = String(_interface_name[_interface_name.startIndex..<end_index])
            do {
                switch interface_name {
                case "wl_seat", "wl_shm", "xdg_wm_base", "wl_compositor":
                    print(
                        "wl_registry:bind object: \(message.object), opcode: \(message.opcode) length: \(message.length), name: \(name), interface_name: \(interface_name), verison: \(verison)"
                    )
                    let id = try await self.bind(
                        registry: message.object,
                        name: name, interface_name: interface_name, verison: verison, outbound)
                    print(id)
                default:
                    print(
                        "wl_registry:unhandled", message.object, message.opcode, message.length, name, interface_name,
                        verison)
                }
            } catch {
                print(interface_name, error, type(of: error))
            }
        } else {
            if let error_message = message.message {
                print("Unhandled: \(message)", error_message.getString(at: 0, length: Int(message.length - 8)))
            } else {
                print("Unhandled: \(message)")
            }
        }
    }

    private mutating func bind(
        registry: UInt32, name: UInt32, interface_name: String, verison: UInt32,
        _ outbound: NIOAsyncChannelOutboundWriter<WaylandMessage>
    ) async throws -> UInt32 {
        var contents = ByteBuffer()
        let out = interface_name.getRounded()
        contents.writeInteger(name, endianness: .little, as: UInt32.self)
        contents.writeInteger(UInt32(out.count), endianness: .little, as: UInt32.self)
        contents.writeString(out)
        contents.writeInteger(verison, endianness: .little, as: UInt32.self)
        wayland_current_object_id += 1
        contents.writeInteger(wayland_current_object_id, endianness: .little, as: UInt32.self)
        let guess = UInt16(8 + contents.readableBytes)
        let message = WaylandMessage(
            object: registry, length: guess,
            opcode: WaylandOpCodes.wayland_wl_registry_bind_opcode.value,
            message: contents)
        try await outbound.write(message)
        return wayland_current_object_id
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

func roundup4(_ value: Int) -> Int {
    return (value + 3) & ~3
}

extension String {
    func getRounded() -> String {
        let padding = roundup4(self.count) - self.count
        var copy = self
        for _ in 0..<padding {
            copy.append("\0")
        }
        return copy
    }
}

typealias FD = Int32
