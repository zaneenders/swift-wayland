import Foundation
import NIOCore
import NIOPosix

struct WaylandClientSession: ~Copyable {
    private let outbound: NIOAsyncChannelOutboundWriter<WaylandMessage>
    private var state: State = State()

    internal init(
        _ outbound: NIOAsyncChannelOutboundWriter<WaylandMessage>
    ) {
        self.outbound = outbound
    }
}

// MARK: Setup
extension WaylandClientSession {

    /// Called before messages are recieved.
    /// Setus up iniital state and connection phase
    internal mutating func setupPhase() async throws {
        self.state.wayland_wl_registry_id = self.state.nextId()
        try await setupRegistry(id: self.state.wayland_wl_registry_id!)
    }

    private func setupRegistry(id: UInt32) async throws {
        // Setup regisstry
        var contents = ByteBuffer()
        contents.writeInteger(id, endianness: .little, as: UInt32.self)
        let message = WaylandMessage(
            object: self.state.wayland_display_object_id,
            opcode: WaylandOpCodes.get_registry.value,
            message: contents)
        try await outbound.write(message)
    }
}

// MARK: Message
extension WaylandClientSession {

    /// Responsible for handling each message
    internal mutating func handle(message: WaylandMessage) async throws {
        switch message.object {
        case self.state.wayland_display_object_id:
            displayObjectEvent(message)
        case self.state.wayland_wl_registry_id:
            try await registryEvent(message)
        case self.state.wl_xdg_wm_base_object_id:
            switch message.opcode {
            case WaylandOpCodes.wayland_xdg_wm_base_event_ping.value:
                print("TODO: send pong")
            default:
                print("Unknown wl_xdg_wm_base_object_id message, opcode: \(message.opcode)")
            }
        case self.state.xdg_top_surface_id:
            switch message.opcode {
            case 0:
                let id = self.state.xdg_top_surface_id!
                guard var contents = message.message else {
                    print("xdg_top_surface_id[\(id)]: failed")
                    return
                }
                guard let width = contents.readInteger(endianness: .little, as: UInt32.self) else {
                    print("xdg_top_surface_id[\(id)]: failed, width")
                    return
                }
                guard let height = contents.readInteger(endianness: .little, as: UInt32.self) else {
                    print("xdg_top_surface_id[\(id)]: failed, height")
                    return
                }
                self.state.width = Int(width)
                self.state.height = Int(height)
                print("xdg_top_surface_id[\(id)]: \(width), \(height)")
            default:
                print("Unknown: xdg_top_surface_id")
            }
        case self.state.xdg_surface_object_id:
            switch message.opcode {
            case WaylandOpCodes.wayland_xdg_surface_event_configure.value:
                var copy = message.message!
                let value = copy.readInteger(as: UInt32.self)!
                do {
                    try await xdgSurfaceEvent(value)
                    try await renderFrame(height: self.state.height, width: self.state.width)
                } catch {
                    print(error)
                }
            default:
                print("Unknown: xdg_surface_object_id")
            }
        default:
            if let error_message = message.message {
                print(
                    "unhandled: Object: \(message.object), opcode: \(message.opcode), message: \(error_message.getString(at: 0, length: Int(message.length - WaylandMessage.headerSize)))"
                )
            } else {
                print("unhandled: Object: \(message.object), opcode: \(message.opcode), Unhandled: \(message)")
            }
        }

        // State transtions
        if !self.state.surfaceComplete && self.state.bindComplete {
            print("Bind State Complete")
            do {
                self.state.wl_surface_object_id = self.state.nextId()
                try await setupSurface(id: self.state.wl_surface_object_id!)
                self.state.xdg_surface_object_id = self.state.nextId()
                try await getXDGSurface(id: self.state.xdg_surface_object_id!)
                self.state.xdg_top_surface_id = self.state.nextId()
                try await xdgGetTopSurface(id: self.state.xdg_top_surface_id!)
                try await surfaceCommit()
            } catch {
                print(error)
                throw WaylandSetupError.unableToSetupSurface
            }
            print("Surface setup Complete")
        }
    }

    private mutating func renderFrame(height: Int, width: Int) async throws {
        let pixels = height * width * 4
        let pool_id: UInt32
        self.state.shared_canvas.resize(pixels: pixels * 2)
        if self.state.frame_counter.isMultiple(of: 2) {
            self.state.shared_canvas.draw(.front, height: height, width: width)
        } else {
            self.state.shared_canvas.draw(.back, height: height, width: width)
        }
        pool_id = try await createPool(fd: Int(self.state.shared_canvas.fd), pixels: UInt32(pixels))
        let buffer_id = try await poolCreateBuffer(pool_id)
        try await wayland_wl_surface_attach(buffer_id)
        try await wayland_wl_surface_damage_buffer()
        try await wayland_wl_surface_commit()
        try await release_buffer(buffer_id)
        print("Frame count: \(self.state.frame_counter)")
        self.state.frame_counter += 1
    }

    private mutating func displayObjectEvent(_ message: WaylandMessage) {
        guard message.object == self.state.wayland_display_object_id else {
            return
        }
        switch message.opcode {
        case WaylandOpCodes.wayland_wl_display_error_event.value:
            if let error_message = message.message {
                print(
                    "wl_display: Error",
                    error_message.getString(at: 0, length: Int(message.length - WaylandMessage.headerSize)))
            } else {
                print("wl_display: Error", message.length)
            }
        default:
            ()
        }
    }

    mutating func registryEvent(_ message: WaylandMessage) async throws {
        guard message.object == self.state.wayland_wl_registry_id else {
            return
        }
        switch message.opcode {
        case WaylandOpCodes.registry_event_global.value:
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
                    let id = self.state.nextId()
                    try await self.sendBind(
                        registry: message.object, id: id, name: name,
                        interface_name: interface_name, verison: verison)
                    self.state.update(interface_name, id)
                default:
                    print(
                        "wl_registry:unhandled", message.object, message.opcode, message.length, name,
                        interface_name,
                        verison)
                }
            } catch {
                print(interface_name, error, type(of: error))
            }
        default:
            ()
        }
    }

    private func surfaceCommit() async throws {
        let message = WaylandMessage(
            object: self.state.wl_surface_object_id!,
            opcode: WaylandOpCodes.wayland_wl_surface_commit_opcode.value)
        try await outbound.write(message)
    }

    private func xdgGetTopSurface(id: UInt32) async throws {
        var contents = ByteBuffer()
        contents.writeInteger(self.state.xdg_top_surface_id!, endianness: .little, as: UInt32.self)
        let message = WaylandMessage(
            object: self.state.xdg_surface_object_id!,
            opcode: WaylandOpCodes.wayland_xdg_surface_get_toplevel_opcode.value, message: contents)
        try await outbound.write(message)
        print("Top level surface id = \(self.state.xdg_top_surface_id!)")
    }

    private mutating func getXDGSurface(id: UInt32) async throws {
        var contents = ByteBuffer()
        contents.writeInteger(id, endianness: .little, as: UInt32.self)
        contents.writeInteger(self.state.wl_surface_object_id!, endianness: .little, as: UInt32.self)
        let message = WaylandMessage(
            object: self.state.wl_xdg_wm_base_object_id!,
            opcode: WaylandOpCodes.wayland_xdg_wm_base_get_xdg_surface_opcode.value, message: contents)
        try await outbound.write(message)
    }

    private mutating func setupSurface(id: UInt32) async throws {
        var contents = ByteBuffer()
        contents.writeInteger(id, endianness: .little, as: UInt32.self)
        let message = WaylandMessage(
            object: self.state.wl_compositor_object_id!,
            opcode: WaylandOpCodes.wayland_wl_compositor_create_surface_opcode.value, message: contents)
        try await outbound.write(message)
    }

    private mutating func release_buffer(
        _ buffer_id: UInt32
    ) async throws {
        //  store_old_id(state->old_wl_buffers, &state->old_wl_buffers_len, wl_buffer);
        try await wayland_wl_destroy_buffer(buffer_id)
    }

    private mutating func wayland_wl_destroy_buffer(
        _ buffer_id: UInt32
    )
        async throws
    {
        let wayland_wl_buffer_destroy_opcode: UInt16 = 0
        let msg = WaylandMessage(
            object: buffer_id,
            opcode: wayland_wl_buffer_destroy_opcode)
        try await outbound.write(msg)
    }

    private mutating func wayland_wl_surface_commit()
        async throws
    {
        let wayland_wl_surface_commit_opcode: UInt16 = 6
        let msg = WaylandMessage(
            object: self.state.wl_surface_object_id!,
            opcode: wayland_wl_surface_commit_opcode)
        try await outbound.write(msg)
    }

    private mutating func wayland_wl_surface_damage_buffer()
        async throws
    {
        // wayland_wl_surface_damage_buffer(fd, state -> wl_surface, 0, 0, INT32_MAX, INT32_MAX)
        var contents = ByteBuffer()
        contents.writeInteger(0, endianness: .little, as: UInt32.self)
        contents.writeInteger(0, endianness: .little, as: UInt32.self)
        contents.writeInteger(UInt32(Int32.max), endianness: .little, as: UInt32.self)
        contents.writeInteger(UInt32(Int32.max), endianness: .little, as: UInt32.self)
        let wayland_wl_surface_damage_buffer_opcode: UInt16 = 9
        let msg = WaylandMessage(
            object: self.state.wl_surface_object_id!,
            opcode: wayland_wl_surface_damage_buffer_opcode,
            message: contents)
        try await outbound.write(msg)
    }

    private mutating func wayland_wl_surface_attach(
        _ buffer: UInt32
    )
        async throws
    {
        var contents = ByteBuffer()
        contents.writeInteger(buffer, endianness: .little, as: UInt32.self)
        contents.writeInteger(0, endianness: .little, as: UInt32.self)
        contents.writeInteger(0, endianness: .little, as: UInt32.self)
        let wayland_wl_surface_attach_opcode: UInt16 = 1
        let msg = WaylandMessage(
            object: self.state.wl_surface_object_id!,
            opcode: wayland_wl_surface_attach_opcode,
            message: contents)
        try await outbound.write(msg)
    }

    private mutating func poolCreateBuffer(_ pool_id: UInt32) async throws
        -> UInt32
    {
        var contents = ByteBuffer()
        let bufferId = self.state.nextId()
        contents.writeInteger(bufferId, endianness: .little, as: UInt32.self)
        let offset: UInt32 = 0
        contents.writeInteger(offset, endianness: .little, as: UInt32.self)
        let width: UInt32 = UInt32(self.state.width)
        contents.writeInteger(width, endianness: .little, as: UInt32.self)
        let height: UInt32 = UInt32(self.state.height)
        contents.writeInteger(height, endianness: .little, as: UInt32.self)
        let stride: UInt32 = 4 * width
        contents.writeInteger(stride, endianness: .little, as: UInt32.self)
        let wayland_format_xrgb8888: UInt32 = 1
        contents.writeInteger(wayland_format_xrgb8888, endianness: .little, as: UInt32.self)

        let wayland_wl_shm_pool_create_buffer_opcode: UInt16 = 0
        let msg = WaylandMessage(
            object: pool_id,
            opcode: wayland_wl_shm_pool_create_buffer_opcode,
            message: contents)
        try await outbound.write(msg)
        return bufferId
    }

    private mutating func createPool(fd: Int, pixels: UInt32) async throws -> UInt32 {
        var contents = ByteBuffer()
        let pool_id = self.state.nextId()
        contents.writeInteger(pool_id, endianness: .little, as: UInt32.self)
        contents.writeInteger(pixels, endianness: .little, as: UInt32.self)
        let message = WaylandMessage(
            object: self.state.wl_shm_object_id!,
            opcode: WaylandOpCodes.wayland_wl_shm_create_pool_opcode.value,
            message: contents,
            fd: fd)
        try await outbound.write(message)
        return pool_id
    }

    private mutating func xdgSurfaceEvent(_ value: UInt32) async throws {
        print("TODO: STATE Change")
        var contents = ByteBuffer()
        contents.writeInteger(value, endianness: .little, as: UInt32.self)
        let message = WaylandMessage(
            object: self.state.xdg_surface_object_id!,
            opcode: WaylandOpCodes.wayland_xdg_surface_ack_configure_opcode.value,
            message: contents)
        try await outbound.write(message)
    }

    private func sendBind(registry: UInt32, id: UInt32, name: UInt32, interface_name: String, verison: UInt32)
        async throws
    {
        var contents = ByteBuffer()
        let out = interface_name.getRounded()
        contents.writeInteger(name, endianness: .little, as: UInt32.self)
        contents.writeInteger(UInt32(out.count), endianness: .little, as: UInt32.self)
        contents.writeString(out)
        contents.writeInteger(verison, endianness: .little, as: UInt32.self)
        contents.writeInteger(id, endianness: .little, as: UInt32.self)
        let message = WaylandMessage(
            object: registry,
            opcode: WaylandOpCodes.wayland_wl_registry_bind_opcode.value,
            message: contents)
        try await outbound.write(message)
    }
}
