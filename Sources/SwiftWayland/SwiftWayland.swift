import Foundation
import NIOCore
import NIOPosix

@main
struct SwiftWayland {

    var state: State = State()

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
                self.state.wayland_wl_registry_id = try await onConnect(outbound)
                self.state.frame_buffer_fd = setupFrameBuffer()
                // FIXME: there is an `unsafe` call here but the swift-format is merging it with `message`
                for try await message in inbound {
                    await handleWaylandResponse(message, outbound)
                    if self.state.bindComplete {
                        print("Bind State Complete")
                        try await setupSurface(outbound)
                        try await getXDGSurface(outbound)
                        try await xdgGetTopSurface(outbound)
                        try await surfaceCommit(outbound)
                    }
                }
                print("Close")
            }
            print("Goodbye")
        } catch {
            print(error)
        }
    }
    private mutating func surfaceCommit(
        _ outbound: NIOAsyncChannelOutboundWriter<WaylandMessage>
    ) async throws {
        let message = WaylandMessage(
            object: self.state.wl_surface_object_id!, length: 8,
            opcode: WaylandOpCodes.wayland_wl_surface_commit_opcode.value, message: nil)
        try await outbound.write(message)
    }

    private mutating func xdgGetTopSurface(
        _ outbound: NIOAsyncChannelOutboundWriter<WaylandMessage>
    ) async throws {
        var contents = ByteBuffer()
        self.state.wayland_current_object_id += 1
        self.state.xdg_top_surface_id = self.state.wayland_current_object_id
        contents.writeInteger(self.state.xdg_top_surface_id!, endianness: .little, as: UInt32.self)
        let message = WaylandMessage(
            object: self.state.xdg_surface_object_id!, length: UInt16(8 + contents.readableBytes),
            opcode: WaylandOpCodes.wayland_xdg_surface_get_toplevel_opcode.value, message: contents)
        try await outbound.write(message)
    }

    private mutating func getXDGSurface(
        _ outbound: NIOAsyncChannelOutboundWriter<WaylandMessage>
    ) async throws {
        self.state.wayland_current_object_id += 1
        var contents = ByteBuffer()
        self.state.xdg_surface_object_id = self.state.wayland_current_object_id
        contents.writeInteger(self.state.wayland_current_object_id, endianness: .little, as: UInt32.self)
        contents.writeInteger(self.state.wl_surface_object_id!, endianness: .little, as: UInt32.self)
        let message = WaylandMessage(
            object: self.state.wl_xdg_wm_base_object_id!, length: UInt16(8 + contents.readableBytes),
            opcode: WaylandOpCodes.wayland_xdg_wm_base_get_xdg_surface_opcode.value, message: contents)
        try await outbound.write(message)
    }

    private mutating func setupSurface(
        _ outbound: NIOAsyncChannelOutboundWriter<WaylandMessage>
    ) async throws {
        self.state.wayland_current_object_id += 1
        var contents = ByteBuffer()
        self.state.wl_surface_object_id = self.state.wayland_current_object_id
        contents.writeInteger(self.state.wayland_current_object_id, endianness: .little, as: UInt32.self)
        let message = WaylandMessage(
            object: self.state.wl_compositor_object_id!, length: UInt16(8 + contents.readableBytes),
            opcode: WaylandOpCodes.wayland_wl_compositor_create_surface_opcode.value, message: contents)
        try await outbound.write(message)
    }

    private mutating func handleWaylandResponse(
        _ message: WaylandMessage,
        _ outbound: NIOAsyncChannelOutboundWriter<WaylandMessage>
    ) async {
        if message.object == self.state.wayland_display_object_id
            && message.opcode == WaylandOpCodes.wayland_wl_display_error_event.value
        {
            print("wl_display: Error", message.length)
            if let error_message = message.message {
                print(error_message.getString(at: 0, length: Int(message.length - 8)))
            }
        } else if message.object == self.state.wayland_wl_registry_id
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
                    self.state.update(interface_name, id)
                default:
                    /*
                    print(
                        "wl_registry:unhandled", message.object, message.opcode, message.length, name, interface_name,
                        verison)
                    */
                    ()
                }
            } catch {
                print(interface_name, error, type(of: error))
            }
        } else if message.object == self.state.wl_xdg_wm_base_object_id
            && message.opcode == WaylandOpCodes.wayland_xdg_wm_base_event_ping.value
        {
            print("TODO: send pong")
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
        self.state.wayland_current_object_id += 1
        contents.writeInteger(self.state.wayland_current_object_id, endianness: .little, as: UInt32.self)
        let guess = UInt16(8 + contents.readableBytes)
        let message = WaylandMessage(
            object: registry, length: guess,
            opcode: WaylandOpCodes.wayland_wl_registry_bind_opcode.value,
            message: contents)
        try await outbound.write(message)
        return self.state.wayland_current_object_id
    }

    private mutating func onConnect(_ outbound: NIOAsyncChannelOutboundWriter<WaylandMessage>) async throws -> UInt32 {
        var contents = ByteBuffer()
        self.state.wayland_current_object_id += 1
        contents.writeInteger(self.state.wayland_current_object_id, endianness: .little, as: UInt32.self)
        let message = WaylandMessage(
            object: self.state.wayland_display_object_id,
            length: UInt16(8 + contents.readableBytes),
            opcode: WaylandOpCodes.get_registry.value,
            message: contents)
        try await outbound.write(message)
        return self.state.wayland_current_object_id
    }

    private func setupFrameBuffer() -> FD {
        let shared_name = UUID().uuidString
        let shared_fd = unsafe shm_open(shared_name, O_RDWR | O_EXCL | O_CREAT, 0600)
        unsafe shm_unlink(shared_name)
        let pixels = self.state.height * self.state.width * 4
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

extension SwiftWayland {
    struct State {
        let wayland_display_object_id: UInt32 = 1
        var wayland_wl_registry_id: UInt32? = nil
        var wayland_current_object_id: UInt32 = 1
        var frame_buffer_fd: Int32!

        var wl_seat_object_id: UInt32? = nil
        var wl_shm_object_id: UInt32? = nil
        var wl_xdg_wm_base_object_id: UInt32? = nil
        var wl_compositor_object_id: UInt32? = nil
        var wl_surface_object_id: UInt32? = nil
        var xdg_surface_object_id: UInt32? = nil
        var xdg_top_surface_id: UInt32? = nil

        var height: Int = 800
        var width: Int = 600

        mutating func update(_ interface_name: String, _ object: UInt32) {
            switch interface_name {
            case "wl_seat":
                self.wl_seat_object_id = object
            case "wl_shm":
                self.wl_shm_object_id = object
            case "xdg_wm_base":
                self.wl_xdg_wm_base_object_id = object
            case "wl_compositor":
                self.wl_compositor_object_id = object
            default:
                ()
            }

        }

        var bindComplete: Bool {
            self.wl_surface_object_id == nil && self.wl_compositor_object_id != nil && self.wl_shm_object_id != nil
                && self.wl_xdg_wm_base_object_id != nil
        }
    }
}
